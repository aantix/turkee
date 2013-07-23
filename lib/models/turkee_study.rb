module Turkee
  class TurkeeStudy < ActiveRecord::Base
    GOLD_RESPONSE_INDEX = 3
    attr_accessible :turkee_task_id, :feedback, :gold_response if ActiveRecord::VERSION::MAJOR < 4

    def approve?
      words = feedback.split(/\W+/)
      gold_response.present? ? (gold_response == words[GOLD_RESPONSE_INDEX]) : true
    end
  end
end