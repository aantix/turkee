require "spec_helper"

describe Turkee::TurkeeTask, :vcr do

  before do
    RTurk.setup(ENV['AWSACCESSKEYID'], ENV['AWSSECRETACCESSKEY'], :sandbox => sandbox)
    Timecop.freeze(Time.local(2015, 2, 19, 16, 42, 00))
  end

  after do
    Timecop.return
  end

  describe ".create_hit" do
    let(:sandbox) { true }

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
                                       turkable_id: turkable.id,
                                       hit_num_assignments: 3
                                      ) }

    it "imports all assignments for the hit" do
      expect { task.import_assignments }.to change {
        Turkee::TurkeeAssignment.count
      }.by(3)
    end
  end

  describe "#process_hit" do
    let(:sandbox) { false }

    let(:turkable) { TestTargetObject.create }
    let(:task) { TestTurkeeTask.create(hit_id: "3TZDZ3Y0JSGB2SHI1XUVU2LFVT791L",
                                       turkable_type: turkable.class.name,
                                       turkable_id: turkable.id,
                                       hit_num_assignments: 3
                                      ) }
    before do
      hit = RTurk::Hit.new(task.hit_id)
      task.import_assignments
    end

    it "updates target object" do
      expect { task.process_hit }.to change {
        turkable.reload.category
      }.to("Water Filters - Faucet Filters")
    end
  end
end
