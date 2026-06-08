# An AI-negotiated meeting between two users. The requester's "AI secretary" picks a
# recipient and writes a pitch; the recipient's "AI secretary" accepts or declines it.
# Profile text is snapshotted at proposal time so the Matches page stays accurate even
# if either user later edits their interests.
#
# Schema (see db/schema.rb for the authoritative version):
#   requester_id  :integer not null  (FK -> users)
#   recipient_id  :integer nullable  (FK -> users; nil on :error proposals where
#                                     the round died before a target was picked.
#                                     An :error row CAN have a recipient when the
#                                     target was chosen but their secretary failed
#                                     to evaluate the pitch.)
#   status        :integer not null  (enum below)
#   pitch / decision_reason   :text    nullable
#   *_profile_snapshot        :text    nullable
#   meeting_at                :datetime nullable (set when a calendar event is made)
#   calendar_event_id/_link   :string  nullable
#   calendar_created          :boolean not null  default false
class MeetingProposal < ApplicationRecord
  # Don't pitch the same ordered pair again within this window (anti-spam).
  # Tunable via the MATCHMAKING_RECENCY_WINDOW_SECONDS env var so the window can be
  # widened in production or kept short for live demos (the default lets matchmaking
  # be re-run back-to-back).
  RECENCY_WINDOW = ENV.fetch("MATCHMAKING_RECENCY_WINDOW_SECONDS", 10).to_i.seconds

  belongs_to :requester, class_name: "User"
  belongs_to :recipient, class_name: "User", optional: true

  # :error rows record a round that couldn't complete (model rate-limited,
  # unparseable AI output, no candidates, etc.) so the failure shows up on the
  # Matches page instead of vanishing.
  enum :status, { pending: 0, accepted: 1, declined: 2, error: 3 }

  validate :requester_and_recipient_differ

  # Proposals the user is party to, on either side. Also the authorization boundary.
  scope :for_user, ->(user) {
    where("requester_id = :id OR recipient_id = :id", id: user.id)
  }
  scope :recent, -> { order(created_at: :desc) }

  # Has this exact (requester -> recipient) direction been proposed recently?
  # Errors don't count — they shouldn't gate a real retry.
  def self.recently_proposed_between?(requester, recipient)
    where(requester_id: requester.id, recipient_id: recipient.id)
      .where.not(status: :error)
      .where(created_at: RECENCY_WINDOW.ago..)
      .exists?
  end

  # The party who is not the given user. Nil if this is an error row that never
  # picked a recipient.
  def other_party(user)
    return recipient if user.id == requester_id
    requester
  end

  private

  def requester_and_recipient_differ
    return if recipient_id.nil?
    errors.add(:recipient_id, "can't be the same as the requester") if requester_id == recipient_id
  end
end
