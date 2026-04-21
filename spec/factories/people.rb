FactoryBot.define do
  factory :person do
    sequence(:name)  { |n| "Person #{n}" }
    sequence(:email) { |n| "person#{n}@example.com" }
    timezone               { "America/Chicago" }
    preferred_start_hour   { 9 }
    preferred_end_hour     { 21 }
    frequency_weeks        { 4.0 }
    notes                  { nil }
  end
end
