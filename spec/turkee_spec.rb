require 'spec_helper'

describe Turkee::TurkeeTask do
  class TestTask < ActiveRecord::Base
    def self.abstract_class
      true
    end

    attr_accessor :description
  end

  class Survey < ActiveRecord::Base
    def self.abstract_class
      true
    end

    def self.hit_complete(hit)
    end
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

  describe ".set_complete?" do
    before do
      @hit = RTurk::Hit.new(123)
    end
    context "completed hits" do
      before do
        @turkee_task = FactoryGirl.create(:turkee_task,
                                          :hit_num_assignments => 100,
                                          :completed_assignments => 100)
      end

      it "marks the turkee task as complete" do
        @hit.should_receive(:dispose!).once
        Survey.should_receive(:hit_complete).once
        @turkee_task.set_complete?(@hit, [Survey])
        @turkee_task.complete.should be_true
      end
    end

    context "incomplete hits" do
      before do
        @turkee_task = FactoryGirl.create(:turkee_task,
                                          :hit_num_assignments => 99,
                                          :completed_assignments => 100)
      end

      it "keeps the turkee task as incomplete" do
        @hit.should_not_receive(:dispose!)
        Survey.should_not_receive(:hit_complete)
        @turkee_task.set_complete?(@hit, [Survey]).should be_false
        @turkee_task.complete.should be_false
      end
    end
  end

  describe ".set_expired?" do
    context "unexpired hits" do
      before do
        @turkee_task = FactoryGirl.create(:turkee_task)
      end

      it "keeps the turkee task as unexpired" do
        Survey.should_not_receive(:hit_expired)
        @turkee_task.set_expired?([Survey])
        @turkee_task.expired.should be_false
      end
    end

    context "expired hits" do
      before do
        @turkee_task = FactoryGirl.create(:turkee_task,
                                          :created_at => 2.days.ago,
                                          :hit_lifetime => 1)
      end

      it "marks the turkee task as expired" do
        Survey.should_receive(:hit_expired)
        @turkee_task.set_expired?([Survey]).should be_true
        @turkee_task.expired.should be_true
      end
    end
  end

  describe ".initiate_callback" do
    before do
      @turkee_task = FactoryGirl.create(:turkee_task)
    end
    it "calls hit_complete for the given callback model" do
      Survey.should_receive(:hit_complete).once
      @turkee_task.initiate_callback(:hit_complete, [Survey])
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
