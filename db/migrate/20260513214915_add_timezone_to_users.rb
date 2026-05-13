class AddTimezoneToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :timezone, :string, default: "America/Chicago", null: false
  end
end
