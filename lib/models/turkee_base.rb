module Turkee
  class TurkeeBase < ActiveRecord::Base
    self.abstract_class = true
  end
end
