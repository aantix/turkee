require 'spec_helper'

describe Turkee::TurkeeFormHelper, :type => :helper do
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

  describe "turkee_form_for" do
    before do
      @survey = create(:test_target_object)
      RTurk.stub(:sandbox?).and_return true

      params = {:assignmentId => '123456', :workerId => '987654'}
      @survey_form = helper.turkee_form_for(@survey, params) do |f|
        f.text_field :answer
      end
    end

    it "displays the passed in assignmentId and workerId " do
      @survey_form.should match(/answer/)
      @survey_form.should match(/type=\"text\"/)
      @survey_form.should match(/assignmentId/)
      @survey_form.should match(/workerId/)
    end

    it "the intial turkee_form_for saved the assignmentId and workerId to a cookie for later retrieval" do
      helper.cookies['assignmentId'].should == '123456'
      helper.cookies['workerId'].should == '987654'

      # Subsequent requests should still return form fields for assignmentId
      survey_form = helper.turkee_form_for(@survey, {}) do |f|
        f.text_field :answer
      end
      survey_form.should match(/123456/)
      survey_form.should match(/987654/)
      survey_form.should match(/assignmentId/)
      survey_form.should match(/workerId/)
    end
  end
end
