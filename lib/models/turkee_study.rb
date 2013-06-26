module Turkee
  class TurkeeStudy < ActiveRecord::Base
    GOLD_RESPONSE_INDEX = 3

    def approve?
      words = feedback.split(/\W+/)
      gold_response.present? ? (gold_response == words[GOLD_RESPONSE_INDEX]) : true
    end
  end
end
