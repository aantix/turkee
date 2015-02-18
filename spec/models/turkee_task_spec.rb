require 'spec_helper'

describe Turkee::TurkeeTask do
  class Survey < ActiveRecord::Base
    def self.abstract_class
      true
    end

    def self.hit_complete(hit)
    end
  end

  # TODO: create_hit should be instance method
  # TODO: unit test for create_hit

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
        @turkee_task.stub(:completed_assignments?) { true }
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
        @turkee_task.stub(:completed_assignments?) { false }
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

  describe "#approval_criteria_for_all_assignments" do
    let(:turkee_task) { FactoryGirl.create(:turkee_task, hit_num_assignments: 3) }
    let(:assignment_1) { FactoryGirl.create(:turkee_assignment, turkee_task_id: turkee_task.id) }
    let(:assignment_2) { FactoryGirl.create(:turkee_assignment, turkee_task_id: turkee_task.id) }
    let(:assignment_3) { FactoryGirl.create(:turkee_assignment, turkee_task_id: turkee_task.id) }
    let(:all_assignments) { [ assignment_1, assignment_2, assignment_3 ] }

    before do
      Turkee::TurkeeTask.stub(:expected_result_field) { :mt_data }
      turkee_task.stub(:turkee_assignments) { all_assignments }
    end

    context "when there are valid assignments" do
      before do
        all_assignments.each do |assignment|
          Turkee::TurkeeTask.stub(:valid_assignment?).with(assignment) { true }
        end
      end

      context "when there is mutual agreement on the answer" do
        before do
          assignment_1.stub(:parsed_response) { { mt_data: "23412" } }
          assignment_2.stub(:parsed_response) { { mt_data: "23412" } }
          assignment_3.stub(:parsed_response) { { mt_data: "12345" } }
        end

        context "when number of assignments meet individual approval criteria over total number of assignments exceeds threshold" do
          it "returns the shared result" do
            result = turkee_task.approval_criteria_for_all_assignments
            expect(result[:mt_data]).to eq("23412")
          end
        end
      end

      context "when there is no mutial agreement on the answer" do
        before do
          assignment_1.stub(:parsed_response) { { mt_data: "23412" } }
          assignment_2.stub(:parsed_response) { { mt_data: "13412" } }
          assignment_3.stub(:parsed_response) { { mt_data: "12345" } }
        end

        it "returns nil" do
          result = turkee_task.approval_criteria_for_all_assignments
          expect(result).to be_nil
        end
      end
    end

    context "when there is no valid assignments" do
      before do
        all_assignments.each do |assignment|
          Turkee::TurkeeTask.stub(:valid_assignment?).with(assignment) { false }
        end
      end

      it "returns nil" do
        expect(turkee_task.approval_criteria_for_all_assignments).to be_nil
      end
    end
  end

  describe "#approvable_assignments" do
    let(:turkee_task) { FactoryGirl.create(:turkee_task, hit_num_assignments: 3) }
    let(:assignment_1) { FactoryGirl.create(:turkee_assignment, turkee_task_id: turkee_task.id) }
    let(:assignment_2) { FactoryGirl.create(:turkee_assignment, turkee_task_id: turkee_task.id) }
    let(:assignment_3) { FactoryGirl.create(:turkee_assignment, turkee_task_id: turkee_task.id) }
    let(:all_assignments) { [ assignment_1, assignment_2, assignment_3 ] }

    before do
      Turkee::TurkeeTask.stub(:expected_result_field) { :mt_data }
      turkee_task.stub(:turkee_assignments) { all_assignments }
      assignment_1.stub(:parsed_response) { { mt_data: "23412" } }
      assignment_2.stub(:parsed_response) { { mt_data: "23412" } }
      assignment_3.stub(:parsed_response) { { mt_data: "12345" } }
      all_assignments.each do |assignment|
        Turkee::TurkeeTask.stub(:valid_assignment?).with(assignment) { true }
      end
    end

    it "returns assignments with the most common value data field" do
      expect(turkee_task.approvable_assignments).to eq([assignment_1, assignment_2])
    end
  end

  describe ".most_common_value" do
    context "with multiple common value groups" do
      it "returns nil" do
        expect(Turkee::TurkeeTask.most_common_value([1 ,2 ,3])).to be_nil
        expect(Turkee::TurkeeTask.most_common_value([1, 1, 2 , 2, 3, 3])).to be_nil
      end
    end

    context "with only one common value group" do
      it "returns the most common value" do
        expect(Turkee::TurkeeTask.most_common_value([3 ,2 ,3])).to eq(3)
      end
    end
  end

  describe "#turkable" do
    let(:test_target_object) { FactoryGirl.create(:test_target_object) }
    let(:turkee_task) { FactoryGirl.create(:turkee_task, turkable_type: "TestTargetObject", turkable_id: test_target_object.id) }

    it "should return the object this turkee task associated with" do
      expect(turkee_task.turkable).to eq(test_target_object)
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

  describe "#completed_assignments?" do
    let(:turkee_task) { FactoryGirl.create(:turkee_task, hit_num_assignments: 3) }

    context "when all turkee assignments are submitted" do
      before do
        FactoryGirl.create(:turkee_assignment, turkee_task_id: turkee_task.id)
        FactoryGirl.create(:turkee_assignment, turkee_task_id: turkee_task.id)
        FactoryGirl.create(:turkee_assignment, turkee_task_id: turkee_task.id)
      end

      it "returns ture" do
        expect(turkee_task.completed_assignments?).to be_true
      end
    end

    context "when not all turkee assignments are submitted" do
      before do
        FactoryGirl.create(:turkee_assignment, turkee_task_id: turkee_task.id)
        FactoryGirl.create(:turkee_assignment, turkee_task_id: turkee_task.id)
      end

      it "returns false" do
        expect(turkee_task.completed_assignments?).to eq(false)
      end
    end
  end
end
