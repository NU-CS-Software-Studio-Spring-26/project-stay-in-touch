FactoryBot.define do
  factory :meeting_proposal do
    association :requester, factory: :user
    association :recipient, factory: :user
    status { :pending }
    pitch  { "Would love to grab 20 minutes to swap notes." }
  end
end
