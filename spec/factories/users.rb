FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password              { "Password1!secure" }
    password_confirmation { "Password1!secure" }

    # Opted into matchmaking with a filled meeting profile.
    trait :matchmaking_ready do
      sequence(:display_name) { |n| "User #{n}" }
      meeting_interests   { "I want feedback on my startup idea and intros to ML researchers." }
      matchmaking_enabled { true }
    end
  end
end
