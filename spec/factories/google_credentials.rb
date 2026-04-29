FactoryBot.define do
  factory :google_credential do
    association :user
    access_token  { "test-access-token" }
    refresh_token { "test-refresh-token" }
    expires_at    { 1.hour.from_now }
  end
end
