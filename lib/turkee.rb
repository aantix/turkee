require 'rubygems'
require 'socket'
require 'lockfile'
require 'active_record'
require 'action_view'
require 'active_support'
require 'action_controller'

module Turkee

  # Model simply tracks what assignments have been imported
  class TurkeeImportedAssignment < ActiveRecord::Base
  end

  class TurkeeTask < ActiveRecord::Base

    # belongs_to :task, :polymorphic => true
    HIT_FRAMEHEIGHT     = 1000

    named_scope :unprocessed_hits, :conditions => ['complete = ?', false]

    # Use this method to go out and retrieve the data for all of the posted Turk Tasks.
    #  Each specific TurkeeTask object (determined by task_type field) is in charge of
    #  accepting/rejecting the assignment and importing the data into their respective tables.
    def self.process_hits(turkee_task = nil)

      begin
        # Using a lockfile to prevent multiple calls to Amazon.
        Lockfile.new('/tmp/turk_processor.lock', :max_age => 3600, :retries => 10) do

          turks = turkee_task.nil? ? TurkeeTask.unprocessed_hits : TurkeeTask.find_all_by_id(turkee_task.id)

          turks.each do |turk|
            hit = RTurk::Hit.new(turk.hit_id)

            hit.assignments.each do |assignment|
              next unless assignment.status == 'Submitted'
              next unless TurkeeImportedAssignment.find_by_assignment_id(assignment.id).nil?

              model   = Object::const_get(turk.task_type)

              # ruby-1.8.7-p302 > Rack::Utils.parse_nested_query("authenticity_token=TfWm9jaKPxjzHHF0YscG4K29S3%2B0n86ii%2Fo4Nh3piJo%3D&survey%5Bresponse%5D=4444&commit=Create")
              # => {"commit"=>"Create", "authenticity_token"=>"TfWm9jaKPxjzHHF0YscG4K29S3+0n86ii/o4Nh3piJo=", "survey"=>{"response"=>"4444"}}
              #
              params     = assignment.answers.map { |k, v| "#{CGI::escape(k)}=#{CGI::escape(v)}" }.join('&')
              param_hash = Rack::Utils.parse_nested_query(params)

              puts "params = #{params.inspect}"
              puts "param_hash = #{param_hash.inspect}"
              result     = model.create(param_hash[turk.task_type.underscore.to_sym])

              # If there's a custom approve? method, see if we should approve the submitted assignment
              #  otherwise just approve it by default
              if result.errors.size > 0
                puts "Errors : #{result.inspect}"
                #assignment.reject!('Failed to enter proper data.')
              elsif result.respond_to?(:approve?)
                puts "Approving : #{result.inspect}"
                #result.approve? ? assignment.approve!('') : assignment.reject!('')
              else
                #assignment.approve!('')
              end

              TurkeeImportedAssignment.create(:assignment_id => assignment.id) rescue nil

            end

            #hit.dispose! if hit.completed_assignments == turk.hit_num_assignments
          end
        end
      rescue Lockfile::MaxTriesLockError => e
        logger.info "TurkTask.process_hits is already running or the lockfile /tmp/turk_processor.lock exists from an improperly shutdown previous process. Exiting method call."
      end

    end

    # Creates a new Mechanical Turk task on AMZN with the given title, desc, etc
    def self.create_hit(host, hit_title, hit_description, typ, num_assignments, reward, lifetime)

      model    = Object::const_get(typ)
      duration = lifetime.to_i
      f_url    = form_url(host, model)

      h = RTurk::Hit.create(:title => hit_title) do |hit|
        hit.assignments = num_assignments
        hit.description = hit_description
        hit.reward      = reward
        hit.lifetime    = duration.days.seconds.to_i
        hit.question(f_url, :frame_height => HIT_FRAMEHEIGHT)
        # hit.qualifications.add :approval_rate, { :gt => 80 }
      end

      TurkeeTask.create(:sandbox             => (Rails.env == 'production' ? false : true),
                        :hit_title           => hit_title,
                        :hit_description     => hit_description,
                        :hit_reward          => reward.to_f,
                        :hit_num_assignments => num_assignments.to_i,
                        :hit_lifetime        => lifetime,
                        :form_url            => f_url,
                        :hit_url             => h.url,
                        :hit_id              => h.id,
                        :task_type           => typ,
                        :complete            => false)

    end

    ##########################################################################################################
    # DON'T PUSH THIS BUTTON UNLESS YOU MEAN IT. :)
    def self.clear_all_turks(force = false)
      # Do NOT execute this function if we're in production mode
      raise "You can only clear turks in the sandbox/development environment unless you pass 'true' for the force flag." if RAILS_ENV == 'production' && !force

      hits = RTurk::Hit.all_reviewable

      logger.info "#{hits.size} reviewable hits. \n"

      unless hits.empty?
        logger.info puts "Approving all assignments and disposing of each hit."

        hits.each do |hit|
          begin
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

    def self.form_url(host, typ)
      @app ||= ActionController::Integration::Session.new
      #@app.send("new_#{typ.to_s.underscore}_url(:host => '#{host}')")  # Not sure why app does respond when :host is passed...
      (host + @app.send("new_#{typ.to_s.underscore}_path")) # Workaround for now. :(
    end

  end


  module TurkeeFormHelper

    # Rails 2.3.8 form_for implementation with the exception of the form action url
    # will always point to the Amazon externalSubmit interface and you must pass in the
    # assignment_id parameter.
    def turkee_form_for(record_or_name_or_array, assignment_id, *args, &proc)
      raise ArgumentError, "Missing block" unless block_given?

      options = args.extract_options!

      case record_or_name_or_array
        when String, Symbol
          object_name = record_or_name_or_array
        when Array
          object = record_or_name_or_array.last
          object_name = ActionController::RecordIdentifier.singular_class_name(object)
          apply_form_for_options!(record_or_name_or_array, options)
          args.unshift object
        else
          object = record_or_name_or_array
          object_name = ActionController::RecordIdentifier.singular_class_name(object)
          apply_form_for_options!([object], options)
          args.unshift object
      end

      # concat(form_tag(options.delete(:url) || {}, options.delete(:html) || {}))
      concat(form_tag(mturk_url))
      concat("<input type=\"hidden\" id=\"assignmentId\" name=\"assignmentId\" value=\"#{assignment_id}\"/>")
      fields_for(object_name, *(args << options), &proc)
      concat('</form>'.html_safe)
      # concat('<script type="text/javascript">Event.observe(window, \'load\', function() {mturk_form_init(\''+object_name.to_s.underscore+'\')});</script>')
      self
    end

    # Returns the external Mechanical Turk url used to post form data.
    #  The sandbox URL is returned unless the Rails environment is in production.
    def mturk_url
      Rails.env == 'production' ? "https://www.mturk.com/mturk/externalSubmit" : "https://workersandbox.mturk.com/mturk/externalSubmit"
    end

    # Returns whether the form fields should be disabled or not (based on the assignment_id)
    def self.disable_form_fields?(assignment_id)
      (assignment_id.nil? || assignment_id == 'ASSIGNMENT_ID_NOT_AVAILABLE')
    end

  end

end

ActionView::Base.send :include, Turkee::TurkeeFormHelper
