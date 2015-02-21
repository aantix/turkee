require 'rubygems'
require 'socket'
require 'rturk'
require 'active_record'
require "active_support/core_ext/object/to_query"

module Turkee
  class TurkeeTask < Turkee::TurkeeBase

    HIT_FRAMEHEIGHT = 1000

    scope :unprocessed_hits, lambda { where('complete = ? AND sandbox = ?', false, RTurk.sandbox?) }

    has_many :turkee_assignments

    def self.threshold
      0.65
    end

    def self.expected_result_field
      raise NotImplementedError.new("expected_result_field method not implemeted")
    end

    def turkable_key
      self.turkable.class.name.underscore.split('/')[-1]
    end

    def self.valid_assignment?(assignment)
      raise NotImplementedError.new("valid_assignment? method not implemeted")
    end

    def approval_criteria_for_all_assignments
      result_field_name = self.class.expected_result_field

      valid_assignments = turkee_assignments.select do |assignment|
        self.class.valid_assignment?(assignment)
      end

      responses = valid_assignments.map do |assig|
        assig.parsed_response[turkable_key][result_field_name]
      end

      common_value = Turkee::TurkeeTask.most_common_value(responses)

      assignments_with_common_value = valid_assignments.select do |assig|
        assig.parsed_response[turkable_key][result_field_name] == common_value
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
          assig.parsed_response[turkable_key][approval_key] == approval_criteria[approval_key]
        end.all?
      end
    end

    def update_target_object(data)
      raise NotImplementedError.new("update_target_object method not implemeted")
    end

    def import_assignments
      hit = RTurk::Hit.new(self.hit_id)

      hit.assignments.each do |mt_assignment|
        response = Rack::Utils.parse_nested_query(mt_assignment.answers.to_query)
        assignment_params = { mt_assignment_id: mt_assignment.assignment_id,
                              worker_id: mt_assignment.worker_id,
                              turkee_task_id: self.id }

        turkee_assignment = Turkee::TurkeeAssignment.where(assignment_params).first_or_create
        turkee_assignment.update_attributes(response: JSON.dump(response), status: mt_assignment.status)
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
        self.set_expired? if !self.set_complete?
      else
        false
      end
    end

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
    def self.create_hit(turkee_task_type, host, hit_title, hit_description, turkable, num_assignments, reward, lifetime,
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

      create(type: turkee_task_type, sandbox: RTurk.sandbox?,
             hit_title: hit_title, hit_description: hit_description,
             hit_reward: reward.to_f, hit_num_assignments: num_assignments.to_i,
             hit_lifetime: lifetime, hit_duration: duration,
             form_url: f_url, hit_url: h.url,
             turkable_type: turkable.class.name, turkable_id: turkable.id,
             hit_id: h.id)
    end

    def turkable
      self.turkable_type.constantize.find(self.turkable_id)
    end

    def complete_task
      self.complete = true
      save!
    end

    def set_complete?
      if completed_assignments?
        hit = RTurk::Hit.new(self.hit_id)
        complete_task
        initiate_callback(:hit_complete)
        return true
      end

      false
    end

    def set_expired?
      if expired?
        self.expired = true
        save!
        initiate_callback(:hit_expired)
      end
    end

    def initiate_callback(method)
      turkable.send(method, self) if turkable.respond_to?(method)
      true
    end

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

    def expired?
      Time.now >= (created_at + hit_lifetime.days)
    end

    def self.submitted?(status)
      (status == 'Submitted')
    end

    def self.assignment_params(answers)
      answers.to_query
    end
  end
end
