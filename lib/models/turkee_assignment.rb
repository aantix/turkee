module Turkee
  class TurkeeAssignment < ActiveRecord::Base
    belongs_to :turkee_task
  end
end
