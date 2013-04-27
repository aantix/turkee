require 'spec_helper'

describe Turkee::TurkeeStudy do

  describe "approve?" do
    before do
      @study = Turkee::TurkeeStudy.new(:feedback => "I really loved the site.  I will tell my mom about it.",
                                       :gold_response => 'the')
    end
    it "approves the task" do
      @study.approve?.should be_true
    end

    it "rejects the task" do
      @study.gold_response = "loved"
      @study.approve?.should be_false
    end
  end
end