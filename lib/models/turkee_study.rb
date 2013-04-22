module Turkee
  class TurkeeStudy < ActiveRecord::Base
    attr_accessible :turkee_task_id, :feedback
  end
end