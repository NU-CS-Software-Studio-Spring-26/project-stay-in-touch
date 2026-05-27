class CreateMeetingProposals < ActiveRecord::Migration[8.1]
  def change
    create_table :meeting_proposals do |t|
      t.references :requester, null: false, foreign_key: { to_table: :users }
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      t.integer :status, null: false, default: 0
      t.text    :pitch
      t.text    :decision_reason
      t.text    :requester_profile_snapshot
      t.text    :recipient_profile_snapshot
      t.datetime :meeting_at
      t.string  :calendar_event_id
      t.string  :calendar_event_link
      t.boolean :calendar_created, null: false, default: false

      t.timestamps
    end

    add_index :meeting_proposals, [:requester_id, :created_at]
    add_index :meeting_proposals, [:recipient_id, :created_at]
    # Supports the 30-day anti-spam lookup for an ordered (requester, recipient) pair.
    add_index :meeting_proposals, [:requester_id, :recipient_id, :created_at]
  end
end
