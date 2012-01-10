require 'spec_helper'


describe Turkee::TurkeeTask do
  #include ActionController::Routing::Routes
  class TestTask < ActiveRecord::Base
    def self.abstract_class; true; end
    attr_accessor :description
  end

  describe "#process_hits" do
    before(:each) do

    end

  end


  describe "#find_model" do

    it "should return a turkee_task mode " do
      returned_data = {:submit => 'Create', "test_task" => {:description => "desc"}}
      Turkee::TurkeeTask.find_model(returned_data).should == TestTask
    end

    it "should return a nil" do
      returned_data = {:submit => 'Create', "another_task_class" => {:description => "desc"}}
      Turkee::TurkeeTask.find_model(returned_data).should be_nil
    end

  end
  
  describe "#assignment_params" do
    it "should encode the params properly" do
      answers = {:test => "abc", :test2 => "this is a test"}
      Turkee::TurkeeTask.assignment_params(answers).should == "test2=this+is+a+test&test=abc"
    end
  end

  describe "#submitted" do
    it "should return true for a submitted status" do
      Turkee::TurkeeTask.submitted?("Submitted").should == true
    end
  end
  
end
