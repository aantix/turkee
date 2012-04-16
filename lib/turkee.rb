require 'rubygems'
require 'socket'
require 'rturk'
require 'lockfile'
require 'active_record'
require 'action_view'
require "active_support/core_ext/object/to_query"
require 'action_controller'

module Turkee

  # Model simply tracks what assignments have been imported
  class TurkeeImportedAssignment < ActiveRecord::Base
  end

  class TurkeeTask < ActiveRecord::Base
    attr_accessible :sandbox, :hit_title, :hit_description, :hit_reward, :hit_num_assignments, :hit_lifetime,
                    :form_url, :hit_url, :hit_id, :task_type, :complete

    HIT_FRAMEHEIGHT     = 1000

    scope :unprocessed_hits, :conditions => ['complete = ?', false]

    # Use this method to go out and retrieve the data for all of the posted Turk Tasks.
    #  Each specific TurkeeTask object (determined by task_type field) is in charge of
    #  accepting/rejecting the assignment and importing the data into their respective tables.
    def self.process_hits(turkee_task = nil)

      begin
        # Using a lockfile to prevent multiple calls to Amazon.
        Lockfile.new('/tmp/turk_processor.lock', :max_age => 3600, :retries => 10) do

          turks = task_items(turkee_task)

          turks.each do |turk|
            hit   = RTurk::Hit.new(turk.hit_id)

            models = []
            hit.assignments.each do |assignment|
              next unless submitted?(assignment.status)
              next unless TurkeeImportedAssignment.find_by_assignment_id(assignment.id).nil?

              params     = assignment_params(assignment.answers)
              param_hash = Rack::Utils.parse_nested_query(params)
              model      = find_model(param_hash)

              next if model.nil?
              puts "param_hash = #{param_hash}"
              result = model.create(param_hash[model.to_s.underscore])

              # If there's a custom approve? method, see if we should approve the submitted assignment
              #  otherwise just approve it by default
              process_result(assignment, result, turk)

              TurkeeImportedAssignment.create(:assignment_id => assignment.id) rescue nil
            end

            check_hit_completeness(hit, turk, models)
          end
        end
      rescue Lockfile::MaxTriesLockError => e
        logger.info "TurkTask.process_hits is already running or the lockfile /tmp/turk_processor.lock exists from an improperly shutdown previous process. Exiting method call."
      end

    end

    # Creates a new Mechanical Turk task on AMZN with the given title, desc, etc
    def self.create_hit(host, hit_title, hit_description, typ, num_assignments, reward, lifetime, qualifications = {}, params = {}, opts = {})

      model    = Object::const_get(typ)
      duration = lifetime.to_i
      f_url    = (opts[:form_url] || form_url(host, model, params))

      h = RTurk::Hit.create(:title => hit_title) do |hit|
        hit.assignments = num_assignments
        hit.description = hit_description
        hit.reward      = reward
        hit.lifetime    = duration.days.seconds.to_i
        hit.question(f_url, :frame_height => HIT_FRAMEHEIGHT)
        unless qualifications.empty?
          qualifications.each do |key, value|
            hit.qualifications.add key, value
          end
        end
      end

      TurkeeTask.create(:sandbox             => RTurk.sandbox?,
                        :hit_title           => hit_title,    :hit_description     => hit_description,
                        :hit_reward          => reward.to_f,  :hit_num_assignments => num_assignments.to_i,
                        :hit_lifetime        => lifetime,     :form_url            => f_url,
                        :hit_url             => h.url,        :hit_id              => h.id,
                        :task_type           => typ,          :complete            => false)

    end

    ##########################################################################################################
    # DON'T PUSH THIS BUTTON UNLESS YOU MEAN IT. :)
    def self.clear_all_turks(force = false)
      # Do NOT execute this function if we're in production mode
      raise "You can only clear turks in the sandbox/development environment unless you pass 'true' for the force flag." if Rails.env == 'production' && !force

      hits = RTurk::Hit.all_reviewable

      logger.info "#{hits.size} reviewable hits. \n"

      unless hits.empty?
        logger.info "Approving all assignments and disposing of each hit."

        hits.each do |hit|
          begin
            puts "Hit.status = #{hit.status}"
            hit.expire! if (hit.status == "Assignable" || hit.status == 'Unassignable')

            hit.assignments.each do |assignment|

              logger.info "Assignment status : #{assignment.status}"

              assignment.approve!('__clear_all_turks__approved__') if assignment.status == 'Submitted'
            end

            turkee_task = TurkeeTask.find_by_hit_id(hit.id)
            if turkee_task
              turkee_task.complete = true
              turkee_task.save
            end

            hit.dispose!
          rescue Exception => e
            # Probably a service unavailable
            logger.error "Exception : #{e.to_s}"
          end
        end
      end

    end

    private

    def logger
      @logger ||= Logger.new($stderr)
    end

    def self.check_hit_completeness(hit, turk, models)
      puts "#### turk.completed_assignments == turk.hit_num_assignments :: #{turk.completed_assignments} == #{turk.hit_num_assignments}"
      if turk.completed_assignments == turk.hit_num_assignments
        hit.dispose!
        turk.complete = true
        turk.save
        models.each { |model| model.hit_complete(turk) if model.respond_to?(:hit_complete) }
      end
    end


    def self.process_result(assignment, result, turk)
      if result.errors.size > 0
        logger.info "Errors : #{result.inspect}"
        assignment.reject!('Failed to enter proper data.')
      elsif result.respond_to?(:approve?)
        logger.debug "Approving : #{result.inspect}"
        increment_complete_assignments(turk)
        result.approve? ? assignment.approve!('') : assignment.reject!('Rejected criteria.')
      else
        increment_complete_assignments(turk)
        assignment.approve!('')
      end
    end

    def self.increment_complete_assignments(turk)
      # Backward compatibility; completed_assignments may not exist in the table
      if turk.respond_to?(:completed_assignments)
        turk.completed_assignments += 1
        turk.save
      end
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
          model = Object::const_get(k.to_s.camelize) rescue next
          return model if model.descends_from_active_record? rescue next
        end
      end
      nil
    end

    def self.form_url(host, typ, params = {})
      @app ||= ActionController::Integration::Session.new(Rails.application)
      url = (host + @app.send("new_#{typ.to_s.underscore}_path")) 
      url = "#{url}?#{params.to_query}" unless params.empty?
      url
    end

  end


  module TurkeeFormHelper

    # Rails 3.1.1 form_for implementation with the exception of the form action url
    # will always point to the Amazon externalSubmit interface and you must pass in the
    # assignment_id parameter.
    def turkee_form_for(record, params, options = {}, &proc)
      raise ArgumentError, "Missing block" unless block_given?
      raise ArgumentError, "turkee_form_for now requires that you pass in the entire params hash, instead of just the assignmentId value. " unless params.is_a?(Hash)
      options[:html] ||= {}

      case record
      when String, Symbol
        object_name = record
        object      = nil
      else
        object      = record.is_a?(Array) ? record.last : record
        object_name = options[:as] || ActiveModel::Naming.param_key(object)
        apply_form_for_options!(record, options)
      end

      options[:html][:remote] = options.delete(:remote) if options.has_key?(:remote)
      options[:html][:method] = options.delete(:method) if options.has_key?(:method)
      options[:html][:authenticity_token] = options.delete(:authenticity_token)

      builder = options[:parent_builder] = instantiate_builder(object_name, object, options, &proc)
      fields_for = fields_for(object_name, object, options, &proc)
      default_options = builder.multipart? ? { :multipart => true } : {}

      output = form_tag(mturk_url, default_options.merge!(options.delete(:html)))
      params.each do |k,v|
        unless k =~ /^action$/i || k =~ /^controller$/i || v.class != String
          output.safe_concat("<input type=\"hidden\" id=\"#{k}\" name=\"#{CGI.escape(k)}\" value=\"#{CGI.escape(v)}\"/>")
        end
      end
      options[:disabled] = true if params[:assignmentId].nil? || Turkee::TurkeeFormHelper::disable_form_fields?(params[:assignmentId])
      output << fields_for
      output.safe_concat('</form>')
    end

    # Returns the external Mechanical Turk url used to post form data based on whether RTurk is cofigured
    #   for sandbox use or not.
    def mturk_url
      RTurk.sandbox? ? "https://workersandbox.mturk.com/mturk/externalSubmit" : "https://www.mturk.com/mturk/externalSubmit"
    end

    # Returns whether the form fields should be disabled or not (based on the assignment_id)
    def self.disable_form_fields?(assignment)
      assignment_id = assignment.is_a?(Hash) ? assignment[:assignmentId] : assignment
      (assignment_id.nil? || assignment_id == 'ASSIGNMENT_ID_NOT_AVAILABLE')
    end
  end

end

ActionView::Base.send :include, Turkee::TurkeeFormHelper
