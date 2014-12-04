require_relative 'base'

module Turkee
  class TurkeeImportedAssignment < Base

    def self.record_imported_assignment(assignment, result, turk)
      TurkeeImportedAssignment.create!(:assignment_id => assignment.id,
                                       :turkee_task_id => turk.id,
                                       :worker_id => assignment.worker_id,
                                       :result_id => result.id)
    end

  end
end
