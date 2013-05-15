FactoryGirl.define do
  factory :survey do |s|
    s.answer "The answer"
    s.created_at Time.now
    s.updated_at Time.now
  end
end