module Turkee
  class TurkeeAssignment < Turkee::TurkeeBase
    APPROVED = "Approved"
    REJECTED = "Rejected"
    SUBMITTED = "Submitted"

    belongs_to :turkee_task

    def approve!(feedback=nil)
      return true if ENV["MT_PRODUCTION"]
      rturk_assignment.approve!(feedback)
      update_attributes(status: APPROVED)
    end

    def reject!(feedback=nil)
      return true if ENV["MT_PRODUCTION"]
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
