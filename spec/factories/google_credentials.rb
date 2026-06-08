FactoryBot.define do
  factory :google_credential do
    association :user
    access_token  { "test-access-token" }
    refresh_token { "test-refresh-token" }
    expires_at    { 1.hour.from_now }

    trait :with_serendipity do
      serendipity_calendar_id { "serendipity-cal-1" }
    end

    trait :with_conflict_calendars do
      availability_calendar_ids { ["work@example.com", "home@example.com"] }
    end
  end
end
