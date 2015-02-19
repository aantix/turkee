require "spec_helper"

describe Turkee::TurkeeTask, :vcr do
  let(:sandbox) { true }
  before do
    RTurk.setup(ENV['AWSACCESSKEYID'], ENV['AWSSECRETACCESSKEY'], :sandbox => sandbox)
  end

  describe ".create_hit" do
    it "creates turkee task record with hit information" do
      target_object = TestTargetObject.create
      expect{ TestTurkeeTask.create_hit(target_object) }.to change{
        TestTurkeeTask.count }.by (1)
      expect(TestTurkeeTask.first.hit_id).not_to be_nil
    end
  end

  describe "#import_assignments" do
    let(:sandbox) { false }
    let(:turkable) { TestTargetObject.create }
    let(:task) { TestTurkeeTask.create(hit_id: "3KTCJ4SCVGBQ9C0CQ6Y0ZORZVSG1ME",
                                       turkable_type: turkable.class.name,
                                       turkable_id: turkable.id
                                      ) }

    it "imports all assignments for the hit" do
      expect { task.import_assignments }.to change {
        Turkee::TurkeeAssignment.count
      }.by(3)
    end
  end

  describe "#process_hit" do

  end
end
