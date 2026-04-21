class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.datetime :occurred_at, null: false
      t.string   :medium,      null: false
      t.string   :title
      t.text     :notes

      t.timestamps
    end

    add_index :events, :occurred_at
  end
end
