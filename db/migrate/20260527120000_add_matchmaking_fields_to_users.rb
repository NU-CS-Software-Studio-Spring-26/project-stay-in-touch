class AddMatchmakingFieldsToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :display_name,        :string
    add_column :users, :meeting_interests,   :text
    add_column :users, :matchmaking_enabled, :boolean, null: false, default: false
    add_index  :users, :matchmaking_enabled

    # Backfill display_name from the email local-part for existing rows.
    # update_columns skips validations/callbacks (no password in memory to validate).
    User.reset_column_information
    User.find_each do |user|
      user.update_columns(display_name: user.email.split("@").first)
    end
  end

  def down
    remove_index  :users, :matchmaking_enabled
    remove_column :users, :matchmaking_enabled
    remove_column :users, :meeting_interests
    remove_column :users, :display_name
  end
end
