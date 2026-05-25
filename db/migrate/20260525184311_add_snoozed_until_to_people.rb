class AddSnoozedUntilToPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :snoozed_until, :date
  end
end
