class OutreachDraft < ApplicationRecord
  belongs_to :user
  belongs_to :person

  validates :body, presence: true
end
