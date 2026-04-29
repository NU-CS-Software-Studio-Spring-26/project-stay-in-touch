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

  validates :email,    presence: true,
                       uniqueness: { case_sensitive: false },
                       format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 12 }, allow_nil: true
end
