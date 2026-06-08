class AddDismissalToMeetingProposals < ActiveRecord::Migration[8.1]
  # Per-viewer dismissal: each party can hide a match from their own Matches
  # screen without affecting the other party's view. Two nullable timestamps,
  # one per side; NULL means "not dismissed".
  def change
    add_column :meeting_proposals, :requester_dismissed_at, :datetime
    add_column :meeting_proposals, :recipient_dismissed_at, :datetime
  end
end
