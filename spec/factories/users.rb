FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password              { "Password1!secure" }
    password_confirmation { "Password1!secure" }
  end
end
