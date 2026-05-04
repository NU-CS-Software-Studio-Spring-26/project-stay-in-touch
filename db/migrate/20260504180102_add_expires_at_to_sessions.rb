class AddExpiresAtToSessions < ActiveRecord::Migration[8.1]
  def up
    add_column :sessions, :expires_at, :datetime
    add_index  :sessions, :expires_at
    # Expire any pre-existing sessions immediately so they don't persist forever.
    execute "UPDATE sessions SET expires_at = CURRENT_TIMESTAMP WHERE expires_at IS NULL"
  end

  def down
    remove_index  :sessions, :expires_at
    remove_column :sessions, :expires_at
  end
end
