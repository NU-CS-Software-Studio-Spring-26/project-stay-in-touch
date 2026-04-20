class CreatePeople < ActiveRecord::Migration[8.1]
  def change
    create_table :people do |t|
      t.string  :name,                 null: false
      t.string  :email,                null: false
      t.string  :timezone,             null: false, default: "America/Chicago"
      t.integer :preferred_start_hour, null: false, default: 9
      t.integer :preferred_end_hour,   null: false, default: 21
      t.decimal :frequency_weeks,      null: false, default: 4.0, precision: 5, scale: 2
      t.text    :notes

      t.timestamps
    end

    add_index :people, "LOWER(email)", unique: true, name: "index_people_on_lower_email"
  end
end
