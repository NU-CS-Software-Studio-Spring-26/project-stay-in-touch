FactoryBot.define do
  factory :event do
    occurred_at { 1.week.ago }
    medium      { "call" }
    title       { "Catch-up" }
    notes       { nil }

    # Default: attach one freshly-built person so validations pass.
    transient do
      people_count { 1 }
    end

    after(:build) do |event, evaluator|
      event.people = build_list(:person, evaluator.people_count) if event.people.empty?
    end
  end
end
