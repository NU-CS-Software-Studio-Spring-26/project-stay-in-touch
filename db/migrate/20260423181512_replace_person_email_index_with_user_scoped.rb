class ReplacePersonEmailIndexWithUserScoped < ActiveRecord::Migration[8.1]
  def change
    remove_index :people, name: "index_people_on_lower_email"
    add_index :people, [:user_id, :email], unique: true,
              name: "index_people_on_user_id_and_email"
  end
end
