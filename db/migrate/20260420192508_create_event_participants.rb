class CreateEventParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :event_participants do |t|
      t.references :person, null: false, foreign_key: true
      t.references :event,  null: false, foreign_key: true

      t.timestamps
    end

    add_index :event_participants, %i[person_id event_id], unique: true
  end
end
