# A logged catch-up — call, coffee, text, etc. One Event may involve many
# People (group dinner, conference call), so the join lives in
# EventParticipant rather than a direct belongs_to.
class Event < ApplicationRecord
  MEDIA = %w[call coffee text video in_person other].freeze

  has_many :event_participants, dependent: :destroy
  has_many :people, through: :event_participants

  validates :occurred_at, presence: true
  validate  :occurred_at_not_in_future
  validates :medium, presence: true, inclusion: { in: MEDIA }
  validate  :must_have_at_least_one_person

  scope :recent, -> { order(occurred_at: :desc) }

  # Display-friendly title fallback when a Person may have left the title blank.
  def display_title
    title.presence || "#{medium.titleize} on #{occurred_at.to_date}"
  end

  private

  def occurred_at_not_in_future
    return if occurred_at.blank?
    return if occurred_at <= Time.current

    errors.add(:occurred_at, "cannot be in the future")
  end

  def must_have_at_least_one_person
    return if event_participants.any? || people.any?

    errors.add(:base, "must include at least one person")
  end
end
