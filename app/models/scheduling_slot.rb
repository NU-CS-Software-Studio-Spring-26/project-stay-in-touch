class SchedulingSlot < ApplicationRecord
  belongs_to :scheduling_negotiation
  belongs_to :confirmed_by, class_name: "User", optional: true

  DURATION_MINUTES = 30

  def confirmed?
    confirmed_by_id.present?
  end

  def ends_at
    starts_at + DURATION_MINUTES.minutes
  end
end
