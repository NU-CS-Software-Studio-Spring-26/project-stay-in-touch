class CreateContactLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :contact_links do |t|
      t.integer :requester_person_id, null: false
      t.integer :recipient_person_id, null: false
      t.integer :status, null: false, default: 0
      t.timestamps
    end
    # Each person record can participate in at most one link (either side).
    add_index :contact_links, :requester_person_id, unique: true
    add_index :contact_links, :recipient_person_id, unique: true
    add_foreign_key :contact_links, :people, column: :requester_person_id
    add_foreign_key :contact_links, :people, column: :recipient_person_id
  end
end
