class AddFavoriteToPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :favorite, :boolean, default: false, null: false
    add_index  :people, [:user_id, :favorite]
  end
end
