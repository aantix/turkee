module Turkee
  class TurkeeAssignment < ActiveRecord::Base
    APPROVED = "Approved"
    REJECTED = "Rejected"
    SUBMITTED = "Submitted"

    belongs_to :turkee_task

    def approve!(feedback=nil)
      rturk_assignment.approve!(feedback)
      update_attributes(status: APPROVED)
    end

    def reject!(feedback=nil)
      rturk_assignment.reject!(feedback)
      update_attributes(status: REJECTED)
    end

    def parsed_response
      JSON.load(response)
    end

    private

    def rturk_assignment
      RTurk::Assignment.new(self.mt_assignment_id)
    end
  end
end
