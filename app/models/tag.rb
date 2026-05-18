class Tag < ApplicationRecord
  belongs_to :user
  has_many :person_tags, dependent: :destroy
  has_many :people, through: :person_tags

  normalizes :name, with: ->(n) { n.strip }
  validates :name, presence: true, length: { maximum: 50 },
                   uniqueness: { scope: :user_id, case_sensitive: false }
end
