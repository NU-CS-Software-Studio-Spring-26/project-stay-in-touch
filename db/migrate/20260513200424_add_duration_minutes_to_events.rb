class AddDurationMinutesToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :duration_minutes, :integer, default: 60, null: false
  end
end
