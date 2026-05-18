class CreatePersonTags < ActiveRecord::Migration[8.1]
  def change
    create_table :person_tags do |t|
      t.references :person, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end
    add_index :person_tags, [:person_id, :tag_id], unique: true
  end
end
