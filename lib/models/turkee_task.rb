require 'rubygems'
require 'socket'
require 'rturk'
require 'lockfile'
require 'active_record'
require "active_support/core_ext/object/to_query"
require 'action_controller'

module Turkee
  class TurkeeTask < ActiveRecord::Base

    HIT_FRAMEHEIGHT = 1000

    scope :unprocessed_hits, lambda { where('complete = ? AND sandbox = ?', false, RTurk.sandbox?) }

    has_many :turkee_assignments

    def self.threshold
      0.65
    end

    def self.expected_result_field
      raise NotImplementedError.new("expected_result_field method not implemeted")
    end

    def self.valid_assignment?(assignment)
      raise NotImplementedError.new("valid_assignment? method not implemeted")
    end

    def approval_criteria_for_all_assignments
      result_field_name = Turkee::TurkeeTask.expected_result_field

      valid_assignments = turkee_assignments.select do |assignment|
        Turkee::TurkeeTask.valid_assignment?(assignment)
      end

      responses = valid_assignments.map do |assig|
        assig.parsed_response[result_field_name]
      end

      common_value = Turkee::TurkeeTask.most_common_value(responses)

      assignments_with_common_value = valid_assignments.select do |assig|
        assig.parsed_response[result_field_name] == common_value
      end

      if (assignments_with_common_value.count / hit_num_assignments.to_f) > Turkee::TurkeeTask.threshold && common_value
        { result_field_name => common_value }
      else
        nil
      end
    end

    def approvable_assignments
      approval_criteria = approval_criteria_for_all_assignments
      turkee_assignments.select do |assig|
        approval_criteria.keys.map do |approval_key|
          assig.parsed_response[approval_key] == approval_criteria[approval_key]
        end.all?
      end
    end

    # Use this method to go out and retrieve the data for all of the posted Turk Tasks.
    #  Each specific TurkeeTask object (determined by task_type field) is in charge of
    #  accepting/rejecting the assignment and importing the data into their respective tables.
    # def self.process_hits(turkee_task = nil)

    # begin
    # # Using a lockfile to prevent multiple calls to Amazon.
    # Lockfile.new('/tmp/turk_processor.lock', :max_age => 3600, :retries => 10) do

    # turks = task_items(turkee_task)
    # instance = nil
    # turks.each do |turk|
    # hit = RTurk::Hit.new(turk.hit_id)
    # params = self.extract_common_values(hit.assignments)
    # next if params.empty?
    # callback_models = Set.new
    # hit.assignments.each do |assignment|
    # # next unless submitted?(assignment.status)
    # next if assignment_exists?(assignment)

    # model, param_hash = map_imported_values(assignment, turk.task_type)
    # next if model.nil?

    # callback_models << model

    # # If there's a custom approve? method, see if we should approve the submitted assignment
    # #  otherwise just approve it by default
    # # turk.process_result(assignment, params["upc"], param_hash["retailer_product"]["upc"]) rescue print("!!" * 100)

    # # TurkeeImportedAssignment.record_imported_assignment(assignment, instance, turk)
    # end
    # instance = RetailerProductQuery::RetailerProduct.find_by_turkee_task_id(turk.id)
    # params.delete("model")
    # instance.update_from_params(params, "mechanical_turk") if instance
    # # turk.set_expired?(callback_models) if !turk.set_complete?(hit, callback_models)
    # end
    # end
    # rescue Lockfile::MaxTriesLockError => e
    # logger.info "TurkTask.process_hits is already running or the lockfile /tmp/turk_processor.lock exists from an improperly shutdown previous process. Exiting method call."
    # end
    # end
    #
    def update_target_object
      raise NotImplementedError.new("update_target_object method not implemeted")
    end

    def import_assignments
      hit = RTurk::Hit.new(self.hit_id)

      hit.assignments.each do |mt_assignment|
        response = Rack::Utils.parse_nested_query(mt_assignment.answers.to_query)
        assignment_params = { assignment_id: mt_assignment.assignment_id,
                              worker_id: mt_assignment.worker_id,
                              turkee_task_id: self.id }

        turkee_assignment = Turkee::TurekeeAssignment.where(assignment_params).first_or_create
        turkee_assignment.update_attributes(response: response)
      end
    end

    def process_hit
      if completed_assignments?
        answer = approval_criteria_for_all_assignments
        return false if answer.nil?

        update_target_object(answer)

        assignments_to_approve = approvable_assignments
        assignments_to_reject = turkee_assignments - approvable_assignments
        assignments_to_approve.each { |assignment| assignment.approve! }
        assignments_to_reject.each { |assignment| assignment.reject! }
        self.set_expired?(turkable) if !turk.set_complete?(hit, turkable)
      else
        false
      end
    end

    # def import_assignments
    # results = {}
    # turkee_task = Turkee::UpcTask.find(upc_task_id) rescue false
    # hit = RTurk::Hit.new(turkee_task.hit_id)
    # mturk_assignments = hit.assignments
    # approved = mturk_assignments.detect { |assign| assign.status == 'Approved' }
    # if approved
    # update_from_params(Rack::Utils.parse_nested_query(approved.answers.to_query)["retailer_product"])
    # return
    # end
    # assignments = mturk_assignments.map { |assignment| Rack::Utils.parse_nested_query(assignment.answers.to_query)["retailer_product"] }
    # assignments[0].keys.each do |key|
    # value_list = assignments.map { |param| param[key] }
    # results[key] = most_common_value(value_list)
    # end if assignments.length > 0
    # results.compact
    # update_from_params(results, "mechanical_turk")
    # if Rails.env == 'production' && results["upc"]
    # approve_hits_upc(results["upc"], mturk_assignments)
    # end
    # end

    # def self.save_imported_values(model, param_hash)
    # key = model.to_s.underscore.gsub('/','_') # Namespaced model will come across as turkee/turkee_study,
    # #  we must translate to turkee_turkee_study"
    # param_hash[:key].delete(:id)
    # model.update(param_hash[:key])
    # end

    # def self.extract_common_values(assignments)
    # results = {}
    # params_list = assignments.map { |assignment| Rack::Utils.parse_nested_query(assignment_params(assignment.answers))["retailer_product"] }
    # params_list[0].keys.each do |key|
    # value_list = params_list.map { |param| param[key] }
    # results[key] = self.most_common_value(value_list)
    # end if params_list.length > 0
    # results.compact
    # end

    def self.most_common_value(responses)
      grouped = responses.group_by do |response|
        response
      end.values

      result = grouped.map do |group|
        { response: group.first, size: group.size }
      end.sort{ |a, b| b[:size] <=> a[:size] }

      if (result.size == 1) or ( result.size > 1 and result[0][:size] != result[1][:size])
        result[0][:response]
      else
        nil
      end
    end

    # Creates a new Mechanical Turk task on AMZN with the given title, desc, etc
    def self.create_hit(host, hit_title, hit_description, turkable, num_assignments, reward, lifetime,
                        duration, f_url, qualifications = {})
      h = RTurk::Hit.create(:title => hit_title) do |hit|
        hit.max_assignments = num_assignments if hit.respond_to?(:max_assignments)
        hit.assignments = num_assignments if hit.respond_to?(:assignments)

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

      create(sandbox: RTurk.sandbox?,
             hit_title: hit_title, hit_description: hit_description,
             hit_reward: reward.to_f, hit_num_assignments: num_assignments.to_i,
             hit_lifetime: lifetime, hit_duration: duration,
             form_url: f_url, hit_url: h.url,
             turkable_type: turkable.class.name, turkable_id: turkable.id,
             hit_id: h.id)
    end

    ##########################################################################################################
    # DON'T PUSH THIS BUTTON UNLESS YOU MEAN IT. :)
    # def self.clear_all_turks(force = false)
    # # Do NOT execute this function if we're in production mode
    # raise "You can only clear turks in the sandbox/development environment unless you pass 'true' for the force flag." if Rails.env == 'production' && !force

    # hits = RTurk::Hit.all

    # logger.info "#{hits.size} reviewable hits. \n"

    # unless hits.empty?
    # logger.info "Approving all assignments and disposing of each hit."

    # hits.each do |hit|
    # begin
    # hit.expire!
    # hit.assignments.each do |assignment|
    # logger.info "Assignment status : #{assignment.status}"
    # assignment.approve!('__clear_all_turks__approved__') if assignment.status == 'Submitted'
    # end

    # turkee_task = TurkeeTask.where(hit_id: hit.id).first
    # turkee_task.complete_task if turkee_task.present?

    # hit.dispose!
    # rescue Exception => e
    # # Probably a service unavailable
    # logger.error "Exception : #{e.to_s}"
    # end
    # end
    # end

    # end

    def turkable
      self.turkable_type.constantize.find(self.turkable_id)
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

    # def process_result(assignment, common_upc, current_upc)
    # self.increment_complete_assignments
    # (common_upc == current_upc && common_upc) ? assignment.approve!('') : assignment.reject!('UPC entered did not match other entries')
    # end

    # def increment_complete_assignments
    # raise "Missing :completed_assignments attribute. Please upgrade Turkee to the most recent version." unless respond_to?(:completed_assignments)

    # self.completed_assignments += 1
    # save
    # end

    def completed_assignments?
      hit_num_assignments == turkee_assignments.count
    end

    def self.form_url(turkable, params)
      raise NotImplementedError.new("form_url method not implemeted")
    end

    private

    def logger
      @logger ||= Logger.new($stderr)
    end

    # def self.map_imported_values(assignment, default_type)
    # params     = assignment_params(assignment.answers)
    # param_hash = Rack::Utils.parse_nested_query(params)

    # model      = find_model(param_hash)
    # model      = default_type.constantize if model.nil?

    # return model, param_hash
    # end

    # def self.assignment_exists?(assignment)
    # TurkeeImportedAssignment.find_by_assignment_id(assignment.id).present?
    # end

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

    # # Returns the default url of the model's :new route
    # def self.form_url(host, typ, params = {})
      # @app ||= ActionDispatch::Integration::Session.new(Rails.application)
      # url = (host + @app.send("new_#{typ.to_s.underscore}_path"))
      # full_url(url, params)
    # end

    # # Appends params to the url as a query string
    # def self.full_url(u, params)
      # url = u
      # url = "#{u}?#{params.to_query}" unless params.empty?
      # url
    # end
  end
end
