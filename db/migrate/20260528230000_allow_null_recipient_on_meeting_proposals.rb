class AllowNullRecipientOnMeetingProposals < ActiveRecord::Migration[8.1]
  # Make recipient_id nullable so the orchestrator can record an :error proposal
  # for a round that died before a target was chosen (e.g. the pitch service was
  # rate-limited and never returned). Visible on the Matches page so silent
  # failures stop being silent.
  def change
    change_column_null :meeting_proposals, :recipient_id, true
  end
end
