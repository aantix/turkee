require 'spec_helper'

describe Turkee::TurkeeTask do
  class TestTask < ActiveRecord::Base
    def self.abstract_class; true; end
    attr_accessor :description
  end

  describe ".completed_assignments?" do
    it "is not complete" do
      turkee_task = FactoryGirl.create(:turkee_task)
      turkee_task.send("completed_assignments?").should be_false
    end

    it "is complete" do
      turkee_task = FactoryGirl.create(:turkee_task, :completed_assignments => 100)
      turkee_task.send("completed_assignments?").should be_true
    end
  end

  describe ".expired?" do
    it "is not expired" do
      turkee_task = FactoryGirl.create(:turkee_task)
      turkee_task.send("expired?").should be_false
    end

    it "is expired" do
      turkee_task = FactoryGirl.create(:turkee_task, :created_at => Time.now - 2.days, :hit_lifetime => 1)
      turkee_task.send("expired?").should be_true

      turkee_task = FactoryGirl.create(:turkee_task, :created_at => Time.now - 1.day, :hit_lifetime => 1)
      turkee_task.send("expired?").should be_true
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
