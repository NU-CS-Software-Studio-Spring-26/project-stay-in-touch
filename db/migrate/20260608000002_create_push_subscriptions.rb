class CreatePushSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :push_subscriptions do |t|
      t.integer :user_id, null: false
      t.text    :endpoint, null: false
      t.string  :p256dh_key, null: false
      t.string  :auth_key,   null: false
      t.timestamps
    end
    add_index :push_subscriptions, :user_id
    add_index :push_subscriptions, :endpoint, unique: true
    add_foreign_key :push_subscriptions, :users
  end
end
