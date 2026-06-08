class CreateSchedulingTables < ActiveRecord::Migration[8.1]
  def change
    create_table :scheduling_negotiations do |t|
      t.integer  :meeting_proposal_id, null: false
      t.integer  :status,              null: false, default: 0
      t.datetime :expires_at,          null: false
      t.timestamps
    end
    add_index :scheduling_negotiations, :meeting_proposal_id, unique: true
    add_index :scheduling_negotiations, [ :status, :expires_at ]
    add_foreign_key :scheduling_negotiations, :meeting_proposals

    create_table :scheduling_slots do |t|
      t.integer  :scheduling_negotiation_id, null: false
      t.datetime :starts_at,                 null: false
      t.integer  :confirmed_by_id
      t.timestamps
    end
    add_index :scheduling_slots, :scheduling_negotiation_id
    add_foreign_key :scheduling_slots, :scheduling_negotiations
    add_foreign_key :scheduling_slots, :users, column: :confirmed_by_id
  end
end
