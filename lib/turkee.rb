module Turkee

  # Model simply tracks what assignments have been imported
  class TurkeeImportedAssignment < ActiveRecord::Base
  end

  class TurkeeTask < ActiveRecord::Base
    belongs_to :task, :polymorphic => true

    HIT_MAX_ASSIGNMENTS = 5
    HIT_REWARD          = 0.05
    HIT_LIFETIME        = 5.days.seconds.to_i
    # in seconds
    HIT_FRAMEHEIGHT     = 1000

    named_scope :unprocessed_hits, :conditions => ['approved is ?',nil]

    def logger
      @logger ||= Logger.new($stderr)
    end

    # Use this method to go out and retrieve the data for all of the posted Turk Tasks.
    #  Each specific TurkeeTask object (determined by task_type field) is in charge of
    #  accepting/rejecting the assignment and importing the data into their respective tables.
    def self.process_hits
      turks = TurkeeTask.unprocessed_hits

      turks.each do |turk|
        hit = RTurk::Hit.new(turk.hit_id)

        hit.assignments.each do |assignment|
          next if assignment.status != 'Submitted'
          next if TurkImportedAssignment.find_by_assignment_id(assignment.id).count > 0


          # See if the model contains the method turkee_approve?
          model   = Object::const_get(turk.task_type)

          # NOW, not sure how I can translate the values retrieved from Turk into a hash similar to
          #  what is posted on a common rails form. Hmmmm...
          #
          # params = {"commit"=>"Create", "authenticity_token"=>"I9SAvjpzyO6x4uR5gq5CwMSyCvazKV/A4hCw+ofvSms=",
          #           "airport"=>{"name"=>"blah blah"}}
          #
          # ruby-1.8.7-p302 > Rack::Utils.parse_nested_query("authenticity_token=TfWm9jaKPxjzHHF0YscG4K29S3%2B0n86ii%2Fo4Nh3piJo%3D&survey%5Bresponse%5D=4444&commit=Create")
          # => {"commit"=>"Create", "authenticity_token"=>"TfWm9jaKPxjzHHF0YscG4K29S3+0n86ii/o4Nh3piJo=", "survey"=>{"response"=>"4444"}}
          #
          params     = assignment.answers.map{|k,v| "#{CGI::escape(k)}=#{CGI::escape(v)}"}.join(',')
          param_hash = Rack::Utils.parse_nested_query(params)
          result     = model.create(param_hash)

          # If there's a custom approve? method, see if we should approve the submitted assignment
          #  otherwise just approve it by default
          if result.errors.size > 0
             assignment.reject!('Failed to enter proper data.')
          elsif result.responds_to?(:approve?)
            result.approve? ? assignment.approve!('') : assignment.reject!('')
          else
            assignment.approve!('')
          end

          TurkeeImportedAssignment.create(:assignment_id => assignment.id)

        end

        # hit.dispose!
      end

    end

    # Creates a new Mechanical Turk  task on AMZN with the given title, desc, etc
    def self.create_turk(hit_title, hit_description, url)

      h = RTurk::Hit.create(:title => hit_title) do |hit|
        hit.assignments = HIT_MAX_ASSIGNMENTS
        hit.description = hit_description
        hit.reward      = HIT_REWARD
        hit.lifetime    = HIT_LIFETIME
        hit.question(url, :frame_height => HIT_FRAMEHEIGHT)
        # pixels for iframe

        # hit.qualifications.add :approval_rate, { :gt => 80 }
      end

    end

    # Finds all of the tasks that haven't been posted to Mechanical Turk and creates HITs for them.
    def self.dequeue_turks(storyboard)
      turks = TurkeeTask.unqueued_tasks_for_storyboard(storyboard.id)

      turks.each do |turk|

        hit = nil
        #HIT_MAX_ASSIGNMENTS.times do
        hit = TurkeeTask.create_turk(turk.hit_title, turk.hit_description, turk.form_url)
        #end

        # Can't update the turk object with a save since it was retrieved
        #  using a 'join' so we can use the class level TurkeeTask update method.
        TurkeeTask.update(turk.id, {:hit_url => hit.url, :hit_id => hit.id}) unless hit.nil?
      end

    end

    # Queue a turkee task.  All tasks get paired to a storyboard location.
    #  E.g. an 'eye-witness account' or a location specific photo.
    def self.queue_turk(typ, title, description, form_url)

      task = TurkeeTask.create(:sandbox         => TURKEETASK_SANDBOX,
                               :hit_title       => title,
                               :hit_description => description,
                               :form_url        => form_url,
                               :task_type       => typ.to_s)

      # Need to append the turk_task_id to the form url and update the task with it.
      new_form_url = form_url =~ /\?/ ? "#{form_url}&turk_task_id=#{task.id}" : "#{form_url}?turk_task_id=#{task.id}"

      if !new_form_url.nil? && !task.nil?
        task.form_url = new_form_url
        task.save
      end
    end

    ##########################################################################################################
    # DON'T PUSH THIS BUTTON UNLESS YOU MEAN IT. :)
    def self.clear_all_turks
      # Do NOT execute this function if we're in production mode
      raise "You can only clear turks in the sandbox/development environment." if RAILS_ENV == 'production'

      hits = RTurk::Hit.all_reviewable

      logger.info "#{hits.size} reviewable hits. \n"

      unless hits.empty?
        logger.info puts "Approving all assignments and disposing of each hit."

        hits.each do |hit|
          #hit.expire!
          begin
            hit.expire! if (hit.status == "Assignable" || hit.status == 'Unassignable')

            hit.assignments.each do |assignment|

              logger.info "Assignment status : #{assignment.status}"

              assignment.approve!('__clear_all_turks__approved__') if assignment.status == 'Submitted'
            end
            hit.dispose!
          rescue Exception => e
            # Probably a service unavailable
            logger.error "Exception : #{e.to_s}"
          end
        end
      end

    end

  end


  module TurkeeFormHelper

    # Rails 2.3.8 form_for implementation with the exception of what url it posts to.
    def turkee_form_for(record_or_name_or_array, *args, &proc)
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
      fields_for(object_name, *(args << options), &proc)
      concat('</form>'.html_safe)
    end

    private
    def mturk_url
      RAILS_ENV == 'development' ? "https://workersandbox.mturk.com/mturk/externalSubmit" : "https://www.mturk.com/mturk/externalSubmit"
    end

  end
end

ActionView::Base.send :include, Turkee::TurkeeFormHelper
