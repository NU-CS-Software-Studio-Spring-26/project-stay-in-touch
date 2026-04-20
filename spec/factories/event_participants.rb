FactoryBot.define do
  factory :event_participant do
    association :person
    association :event
  end
end
