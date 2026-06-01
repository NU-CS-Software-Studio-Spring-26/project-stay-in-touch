# A logged catch-up — call, coffee, text, etc. One Event may involve many
# People (group dinner, conference call), so the join lives in
# EventParticipant rather than a direct belongs_to.
#
# Schema (see db/schema.rb for the authoritative version):
#   occurred_at  :datetime not null  (indexed)
#   medium       :string   not null  (one of Event::MEDIA)
#   title        :string   nullable  (falls back to medium name)
#   notes        :text     nullable
class Event < ApplicationRecord
  MEDIA = %w[call coffee text video in_person other].freeze

  belongs_to :user
  has_many :event_participants, dependent: :destroy
  has_many :people, through: :event_participants

  normalizes :title, with: ->(t) { t.strip }

  validates :occurred_at, presence: true
  validates :medium, presence: true, inclusion: { in: MEDIA }
  validates :title, length: { maximum: 255 }, no_profanity: true, allow_blank: true
  validates :notes, length: { maximum: 5000 }, no_profanity: true, allow_blank: true
  # Server-side guard for the form's duration picker (15–120 min). The DB
  # column is `default: 60, null: false`, so this never rejects normal input;
  # it exists to reject crafted/out-of-range values (e.g. negative or absurd).
  validates :duration_minutes,
            numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 1440 }
  validate  :must_have_at_least_one_person

  scope :recent, -> { order(occurred_at: :desc) }

  def display_title
    title.presence || medium.titleize
  end

  private

  def must_have_at_least_one_person
    return if event_participants.any? || people.any?

    errors.add(:base, "must include at least one person")
  end
end
