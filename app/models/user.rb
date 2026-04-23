class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :people,   dependent: :destroy
  has_many :events,   dependent: :destroy

  normalizes :email, with: ->(e) { e.strip.downcase }

  validates :email,    presence: true,
                       uniqueness: { case_sensitive: false },
                       format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 12 }, allow_nil: true
end
