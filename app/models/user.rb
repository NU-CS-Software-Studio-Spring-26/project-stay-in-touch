class User < ApplicationRecord
  has_secure_password
  has_many :sessions,           dependent: :destroy
  has_many :people,             dependent: :destroy
  has_many :events,             dependent: :destroy
  has_one  :google_credential,  dependent: :destroy

  normalizes :email, with: ->(e) { e.strip.downcase }

  def create_or_update_google_credential!(attrs)
    if google_credential
      google_credential.update!(attrs)
    else
      create_google_credential!(attrs)
    end
  end

  def google_calendar_connected?
    google_credential.present?
  end

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  validate :password_complexity, if: -> { password.present? }

  private

  def password_complexity
    errors.add(:password, "must be more than 10 characters")      if password.length <= 10
    errors.add(:password, "must include at least one uppercase letter") unless password.match?(/[A-Z]/)
    errors.add(:password, "must include at least one lowercase letter") unless password.match?(/[a-z]/)
    errors.add(:password, "must include at least one number")           unless password.match?(/\d/)
    errors.add(:password, "must include at least one special character") unless password.match?(/[^A-Za-z\d\s]/)
  end
end
