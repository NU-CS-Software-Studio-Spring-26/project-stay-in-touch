class GoogleCredential < ApplicationRecord
  belongs_to :user

  validates :access_token,  presence: true
  validates :refresh_token, presence: true
  validates :expires_at,    presence: true

  # Calendly-style "check for conflicts with": the calendars whose free/busy is read
  # when scheduling. Stored as a JSON list so the user can pick several.
  serialize :availability_calendar_ids, type: Array, coder: JSON

  def expired?
    expires_at <= Time.current
  end

  # Calendars to read free/busy from. An empty selection falls back to the user's
  # primary calendar, preserving the original behaviour.
  def conflict_calendar_ids
    ids = availability_calendar_ids.presence
    (ids && ids.any?) ? ids : [ "primary" ]
  end
end
