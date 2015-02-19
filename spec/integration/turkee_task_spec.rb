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

  end

  describe "#process_hit" do

  end
end
