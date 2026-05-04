class Session < ApplicationRecord
  belongs_to :user

  SESSION_DURATION = 30.days

  def expired?
    expires_at.nil? || expires_at <= Time.current
  end
end
