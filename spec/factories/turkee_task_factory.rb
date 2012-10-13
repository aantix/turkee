require 'turkee'
FactoryGirl.define do
  factory :turkee_task, :class => Turkee::TurkeeTask do |s|
    s.hit_url "http://workersandbox.mturk.com/mturk/preview?groupId=248SVGULF395SZ65OC6S6NYNJDXAO5"
    s.sandbox true
    s.task_type "TestTask"
    s.hit_title "Test Title"
    s.hit_description "Test Desc"
    s.hit_id "123"
    s.hit_reward 0.05
    s.completed_assignments 0
    s.hit_num_assignments 100
    s.hit_lifetime 1
    s.hit_duration 1
    s.form_url "http://localhost/test_task/new"
    s.complete false
    s.expired false
    s.created_at Time.now
    s.updated_at Time.now
  end
end