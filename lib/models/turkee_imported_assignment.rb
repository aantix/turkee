require 'active_record'

module Turkee
  class TurkeeImportedAssignment < ActiveRecord::Base
    attr_accessible :assignment_id, :turkee_task_id, :worker_id, :result_id if ActiveRecord::VERSION::MAJOR < 4

    def self.record_imported_assignment(assignment, result, turk)
      TurkeeImportedAssignment.create!(:assignment_id => assignment.id,
                                       :turkee_task_id => turk.id,
                                       :worker_id => assignment.worker_id,
                                       :result_id => result.id)
    end

  end
end