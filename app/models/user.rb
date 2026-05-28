class User < ApplicationRecord
  has_secure_password
  has_many :sessions,           dependent: :destroy
  has_many :people,             dependent: :destroy
  has_many :events,             dependent: :destroy
  has_many :tags,               dependent: :destroy
  has_one  :google_credential,  dependent: :destroy

  # AI-negotiated meeting matchmaking. A user can be on either side of a proposal.
  has_many :requested_proposals, class_name: "MeetingProposal",
                                 foreign_key: :requester_id, dependent: :destroy
  has_many :received_proposals,  class_name: "MeetingProposal",
                                 foreign_key: :recipient_id, dependent: :destroy

  # Users who have opted into matchmaking and written what they want from meetings.
  scope :matchmaking_candidates, -> {
    where(matchmaking_enabled: true).where.not(meeting_interests: [nil, ""])
  }

  DEFAULT_TAGS = %w[Work Family Friends].freeze

  after_create :seed_default_tags

  normalizes :email, with: ->(e) { e.strip.downcase }

  def create_or_update_google_credential!(attrs)
    if google_credential
      google_credential.update!(attrs)
    else
      create_google_credential!(attrs)
    end
  end

  RESET_TOKEN_EXPIRATION = 1.hour

  def generate_reset_token
    raw_token = SecureRandom.urlsafe_base64
    self.reset_token = Digest::SHA256.hexdigest(raw_token)
    self.reset_token_expires_at = Time.current + RESET_TOKEN_EXPIRATION
    save!
    raw_token
  end

  def reset_token_valid?(raw_token)
    reset_token.present? &&
      reset_token_expires_at.present? &&
      reset_token_expires_at > Time.current &&
      reset_token == Digest::SHA256.hexdigest(raw_token)
  end

  def clear_reset_token!
    update!(reset_token: nil, reset_token_expires_at: nil)
  end

  def google_calendar_connected?
    google_credential.present?
  end

  # Opted in AND has written what they want from meetings — required to take part.
  def matchmaking_ready?
    matchmaking_enabled? && meeting_interests.present?
  end

  # Human-readable label shown to other users' AI secretaries and in the UI.
  # Never expose the raw email to the LLM — fall back to the email local-part only.
  def display_label
    display_name.presence || email.split("@").first
  end

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :timezone, presence: true,
                       inclusion: { in: ActiveSupport::TimeZone::MAPPING.values }
  validates :display_name,      length: { maximum: 100 },  allow_blank: true
  validates :meeting_interests, length: { maximum: 2000 }, allow_blank: true

  attr_accessor :skip_password_complexity

  validate :password_complexity, if: -> { password.present? && !skip_password_complexity }

  private

  def password_complexity
    errors.add(:password, "must be more than 10 characters")      if password.length <= 10
    errors.add(:password, "must include at least one uppercase letter") unless password.match?(/[A-Z]/)
    errors.add(:password, "must include at least one lowercase letter") unless password.match?(/[a-z]/)
    errors.add(:password, "must include at least one number")           unless password.match?(/\d/)
    errors.add(:password, "must include at least one special character") unless password.match?(/[^A-Za-z\d\s]/)
  end

  def seed_default_tags
    DEFAULT_TAGS.each { |name| tags.create!(name: name) }
  end
end
