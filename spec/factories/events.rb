FactoryBot.define do
  factory :event do
    association :user
    occurred_at { 1.week.ago }
    medium      { "call" }
    title       { "Catch-up" }
    notes       { nil }

    # Default: attach one freshly-built person so validations pass.
    transient do
      people_count { 1 }
    end

    after(:build) do |event, evaluator|
      if event.people.empty?
        event.people = build_list(:person, evaluator.people_count, user: event.user)
      end
    end
  end
end
