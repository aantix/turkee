require 'spec_helper'

describe Turkee::TurkeeFormHelper, :type => :helper do
  #include RSpec::Rails::HelperExampleGroup
  describe "mturk_url" do
    it "should return sandbox" do
      RTurk.stub(:sandbox?).and_return true
      mturk_url.should match /workersandbox.mturk.com/
    end
    it "should return production url" do
      RTurk.stub(:sandbox?).and_return false
      mturk_url.should match /www.mturk.com/
    end
  end

  describe "turkee_study" do
    before do
      @task = Factory(:turkee_task)
      RTurk.stub(:sandbox?).and_return true
    end

    it "includes the description" do
      helper.stub(:params).and_return {}
      study_form = turkee_study
      study_form.should =~ /Test Desc/
      study_form.should =~ /feedback/
      study_form.should match /workersandbox.mturk.com/
    end

    it "saves the assignmentId to a cookie for later retrieval" do
      helper.stub(:params).and_return({'assignmentId' => '123456'})

      helper.turkee_study

      helper.cookies['assignmentId'].should == '123456'

      # Subsequent requests should still return form fields for assignmentId
      helper.stub(:params).and_return({})
      study_form = helper.turkee_study

      study_form.should =~ /123456/
    end
  end
end
