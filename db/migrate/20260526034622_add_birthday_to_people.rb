class AddBirthdayToPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :birthday, :date
  end
end
