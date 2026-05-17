# A Person you want to stay in touch with. Stores contact identity plus the
# two inputs that drive future reach-out reminders (Serendipity roadmap):
# the preferred-hours window (for availability matching) and a target
# `frequency_weeks` (how often you'd like to catch up).
#
# Schema (see db/schema.rb for the authoritative version):
#   name                  :string  not null
#   email                 :string  not null  (case-insensitive unique index)
#   timezone              :string  not null  default "America/Chicago"  (IANA)
#   preferred_start_hour  :integer not null  default 9    (0..23)
#   preferred_end_hour    :integer not null  default 21   (0..23)
#   frequency_weeks       :decimal not null  default 4.0  precision 5 scale 2
#   notes                 :text    nullable
#   favorite              :boolean not null  default false
class Person < ApplicationRecord
  HOUR_RANGE = (0..23).freeze
  EMAIL_FORMAT = URI::MailTo::EMAIL_REGEXP

  belongs_to :user
  has_many :event_participants, dependent: :destroy
  has_many :events, through: :event_participants

  scope :favorites, -> { where(favorite: true) }

  normalizes :name, with: ->(n) { n.strip }

  validates :name, presence: true, length: { maximum: 255 }
  validates :email,
            presence: true,
            format: { with: EMAIL_FORMAT },
            uniqueness: { scope: :user_id, case_sensitive: false }
  # Store IANA identifiers like "America/Chicago" so the future Serendipity
  # scheduler (Python) can consume the field unchanged.
  validates :timezone,
            presence: true,
            inclusion: { in: ActiveSupport::TimeZone::MAPPING.values }
  validates :preferred_start_hour,
            presence: true,
            numericality: { only_integer: true, in: HOUR_RANGE }
  validates :preferred_end_hour,
            presence: true,
            numericality: { only_integer: true, in: HOUR_RANGE }
  validates :notes, length: { maximum: 5000 }, allow_blank: true
  validates :frequency_weeks,
            presence: true,
            numericality: { greater_than: 0, less_than_or_equal_to: 520 }
  validate  :preferred_window_ordered

  # Most recent Event for this Person, or nil if none yet.
  def latest_event
    events.loaded? ? events.max_by(&:occurred_at) : events.order(occurred_at: :desc).first
  end

  # Days until the next reach-out is "due" per frequency_weeks.
  # Negative values mean overdue; nil when no prior events.
  def days_until_due
    return nil unless latest_event

    deadline = latest_event.occurred_at + (frequency_weeks * 7).days
    ((deadline - Time.current) / 1.day).round
  end

  private

  def preferred_window_ordered
    return if preferred_start_hour.nil? || preferred_end_hour.nil?
    return if preferred_start_hour <= preferred_end_hour

    errors.add(:preferred_end_hour, "must be greater than or equal to preferred_start_hour")
  end
end
