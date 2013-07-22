require 'rubygems'
require 'socket'
require 'rturk'
require 'lockfile'
require 'active_record'
require "active_support/core_ext/object/to_query"
require 'action_controller'

module Turkee

  class TurkeeTask < ActiveRecord::Base
    attr_accessible :sandbox, :hit_title, :hit_description, :hit_reward, :hit_num_assignments, :hit_lifetime, :hit_duration,
                    :form_url, :hit_url, :hit_id, :task_type, :complete if ActiveRecord::VERSION::MAJOR < 4

    HIT_FRAMEHEIGHT = 1000

    scope :unprocessed_hits, lambda { where('complete = ? AND sandbox = ?', false, RTurk.sandbox?) }

    # Use this method to go out and retrieve the data for all of the posted Turk Tasks.
    #  Each specific TurkeeTask object (determined by task_type field) is in charge of
    #  accepting/rejecting the assignment and importing the data into their respective tables.
    def self.process_hits(turkee_task = nil)

      begin
        # Using a lockfile to prevent multiple calls to Amazon.
        Lockfile.new('/tmp/turk_processor.lock', :max_age => 3600, :retries => 10) do

          turks = task_items(turkee_task)

          turks.each do |turk|
            hit = RTurk::Hit.new(turk.hit_id)

            callback_models = Set.new
            hit.assignments.each do |assignment|
              next unless submitted?(assignment.status)
              next if assignment_exists?(assignment)

              model, param_hash = map_imported_values(assignment, turk.task_type)
              next if model.nil?

              callback_models << model

              result = save_imported_values(model, param_hash)

              # If there's a custom approve? method, see if we should approve the submitted assignment
              #  otherwise just approve it by default
              turk.process_result(assignment, result)

              TurkeeImportedAssignment.record_imported_assignment(assignment, result, turk)
            end

            turk.set_expired?(callback_models) if !turk.set_complete?(hit, callback_models)
          end
        end
      rescue Lockfile::MaxTriesLockError => e
        logger.info "TurkTask.process_hits is already running or the lockfile /tmp/turk_processor.lock exists from an improperly shutdown previous process. Exiting method call."
      end

    end

    def self.save_imported_values(model, param_hash)
      key = model.to_s.underscore.gsub('/','_') # Namespaced model will come across as turkee/turkee_study,
                                                #  we must translate to turkee_turkee_study"
      model.create(param_hash[key])
    end

    # Creates a new Mechanical Turk task on AMZN with the given title, desc, etc
    def self.create_hit(host, hit_title, hit_description, typ, num_assignments, reward, lifetime,
                        duration = nil, qualifications = {}, params = {}, opts = {})
      model = typ.to_s.constantize
      f_url = build_url(host, model, params, opts)

      h = RTurk::Hit.create(:title => hit_title) do |hit|
        hit.assignments = num_assignments
        hit.description = hit_description
        hit.reward = reward
        hit.lifetime = lifetime.to_i.days.seconds.to_i
        hit.duration = duration.to_i.hours.seconds.to_i if duration
        hit.question(f_url, :frame_height => HIT_FRAMEHEIGHT)
        unless qualifications.empty?
          qualifications.each do |key, value|
            hit.qualifications.add key, value
          end
        end
      end

      TurkeeTask.create(:sandbox => RTurk.sandbox?,
                        :hit_title => hit_title, :hit_description => hit_description,
                        :hit_reward => reward.to_f, :hit_num_assignments => num_assignments.to_i,
                        :hit_lifetime => lifetime, :hit_duration => duration,
                        :form_url => f_url, :hit_url => h.url,
                        :hit_id => h.id, :task_type => typ,
                        :complete => false)

    end

    ##########################################################################################################
    # DON'T PUSH THIS BUTTON UNLESS YOU MEAN IT. :)
    def self.clear_all_turks(force = false)
      # Do NOT execute this function if we're in production mode
      raise "You can only clear turks in the sandbox/development environment unless you pass 'true' for the force flag." if Rails.env == 'production' && !force

      hits = RTurk::Hit.all

      logger.info "#{hits.size} reviewable hits. \n"

      unless hits.empty?
        logger.info "Approving all assignments and disposing of each hit."

        hits.each do |hit|
          begin
            hit.expire!
            hit.assignments.each do |assignment|
              logger.info "Assignment status : #{assignment.status}"
              assignment.approve!('__clear_all_turks__approved__') if assignment.status == 'Submitted'
            end

            turkee_task = TurkeeTask.find_by_hit_id(hit.id)
            turkee_task.complete_task

            hit.dispose!
          rescue Exception => e
            # Probably a service unavailable
            logger.error "Exception : #{e.to_s}"
          end
        end
      end

    end

    def complete_task
      self.complete = true
      save!
    end

    def set_complete?(hit, models)
      if completed_assignments?
        hit.dispose!
        complete_task
        initiate_callback(:hit_complete, models)
        return true
      end

      false
    end

    def set_expired?(models)
      if expired?
        self.expired = true
        save!
        initiate_callback(:hit_expired, models)
      end
    end

    def initiate_callback(method, models)
      models.each { |model| model.send(method, self) if model.respond_to?(method) }
    end

    def process_result(assignment, result)
      if result.errors.size > 0
        logger.info "Errors : #{result.inspect}"
        assignment.reject!('Failed to enter proper data.')
      elsif result.respond_to?(:approve?)
        logger.debug "Approving : #{result.inspect}"
        self.increment_complete_assignments
        result.approve? ? assignment.approve!('') : assignment.reject!('Rejected criteria.')
      else
        self.increment_complete_assignments
        assignment.approve!('')
      end
    end

    def increment_complete_assignments
      raise "Missing :completed_assignments attribute. Please upgrade Turkee to the most recent version." unless respond_to?(:completed_assignments)

      self.completed_assignments += 1
      save
    end

    private

    def logger
      @logger ||= Logger.new($stderr)
    end

    def self.map_imported_values(assignment, default_type)
      params     = assignment_params(assignment.answers)
      param_hash = Rack::Utils.parse_nested_query(params)

      model      = find_model(param_hash)
      model      = default_type.constantize if model.nil?

      return model, param_hash
    end

    def self.assignment_exists?(assignment)
      TurkeeImportedAssignment.find_by_assignment_id(assignment.id).present?
    end

    def completed_assignments?
      completed_assignments == hit_num_assignments
    end

    def expired?
      Time.now >= (created_at + hit_lifetime.days)
    end

    def self.task_items(turkee_task)
      turkee_task.nil? ? TurkeeTask.unprocessed_hits : Array.new << turkee_task
    end

    def self.submitted?(status)
      (status == 'Submitted')
    end

    def self.assignment_params(answers)
      answers.to_query
    end

    # Method looks at the parameter and attempts to find an ActiveRecord model
    #  in the current app that would match the properties of one of the nested hashes
    #  x = {:submit = 'Create', :iteration_vote => {:iteration_id => 1}}
    #  The above _should_ return an IterationVote model
    def self.find_model(param_hash)
      param_hash.each do |k, v|
        if v.is_a?(Hash)
          model = k.to_s.camelize.constantize rescue next
          return model if model.descends_from_active_record? rescue next
        end
      end
      nil
    end

    # Returns custom URL if opts[:form_url] is specified.  Otherwise, builds the default url from the model's :new route
    def self.build_url(host, model, params, opts)
      if opts[:form_url]
        full_url(opts[:form_url], params)
      else
        form_url(host, model, params)
      end
    end

    # Returns the default url of the model's :new route
    def self.form_url(host, typ, params = {})
      @app ||= ActionController::Integration::Session.new(Rails.application)
      url = (host + @app.send("new_#{typ.to_s.underscore}_path"))
      full_url(url, params)
    end

    # Appends params to the url as a query string
    def self.full_url(u, params)
      url = u
      url = "#{u}?#{params.to_query}" unless params.empty?
      url
    end
  end
end