class CreateOutreachDrafts < ActiveRecord::Migration[8.1]
  def change
    create_table :outreach_drafts do |t|
      t.integer :user_id,   null: false
      t.integer :person_id, null: false
      t.text    :body,      null: false
      t.timestamps
    end
    add_index :outreach_drafts, [ :user_id, :person_id, :created_at ]
    add_foreign_key :outreach_drafts, :users
    add_foreign_key :outreach_drafts, :people
  end
end
