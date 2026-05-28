# An AI-negotiated meeting between two users. The requester's "AI secretary" picks a
# recipient and writes a pitch; the recipient's "AI secretary" accepts or declines it.
# Profile text is snapshotted at proposal time so the Matches page stays accurate even
# if either user later edits their interests.
#
# Schema (see db/schema.rb for the authoritative version):
#   requester_id / recipient_id  :integer not null  (both FK -> users)
#   status                       :integer not null  (enum below)
#   pitch / decision_reason      :text    nullable
#   *_profile_snapshot           :text    nullable
#   meeting_at                   :datetime nullable (set when a calendar event is made)
#   calendar_event_id/_link      :string  nullable
#   calendar_created             :boolean not null  default false
class MeetingProposal < ApplicationRecord
  # Don't pitch the same ordered pair again within this window (anti-spam).
  RECENCY_WINDOW = 30.days

  belongs_to :requester, class_name: "User"
  belongs_to :recipient, class_name: "User"

  enum :status, { pending: 0, accepted: 1, declined: 2, error: 3 }

  validate :requester_and_recipient_differ

  # Proposals the user is party to, on either side. Also the authorization boundary.
  scope :for_user, ->(user) {
    where("requester_id = :id OR recipient_id = :id", id: user.id)
  }
  scope :recent, -> { order(created_at: :desc) }

  # Has this exact (requester -> recipient) direction been proposed recently?
  def self.recently_proposed_between?(requester, recipient)
    where(requester_id: requester.id, recipient_id: recipient.id)
      .where(created_at: RECENCY_WINDOW.ago..)
      .exists?
  end

  # The party who is not the given user.
  def other_party(user)
    user.id == requester_id ? recipient : requester
  end

  private

  def requester_and_recipient_differ
    errors.add(:recipient_id, "can't be the same as the requester") if requester_id == recipient_id
  end
end
