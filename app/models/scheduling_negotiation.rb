class SchedulingNegotiation < ApplicationRecord
  belongs_to :meeting_proposal
  has_many   :scheduling_slots, dependent: :destroy

  enum :status, { pending: 0, confirmed: 1, expired: 2 }

  delegate :requester, :recipient, to: :meeting_proposal

  def parties
    [ requester, recipient ].compact
  end

  def confirmed_slot
    scheduling_slots.where.not(confirmed_by_id: nil).first
  end

  def past_expiry?
    expires_at < Time.current
  end
end
