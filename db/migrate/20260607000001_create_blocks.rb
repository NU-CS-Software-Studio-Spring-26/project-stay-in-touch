class CreateBlocks < ActiveRecord::Migration[8.1]
  def change
    create_table :blocks do |t|
      t.integer :blocker_id, null: false
      t.integer :blocked_id, null: false
      t.timestamps
    end

    add_index :blocks, [ :blocker_id, :blocked_id ], unique: true
    add_index :blocks, :blocked_id

    add_foreign_key :blocks, :users, column: :blocker_id
    add_foreign_key :blocks, :users, column: :blocked_id
  end
end
