class CreatePersonFacts < ActiveRecord::Migration[8.1]
  def change
    create_table :person_facts do |t|
      t.references :person, null: false, foreign_key: true
      t.string :category, null: false
      t.text :body, null: false
      t.date :noted_at
      t.timestamps
    end
    add_index :person_facts, %i[person_id created_at]
  end
end
