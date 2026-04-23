class AddNotNullConstraintToUserIds < ActiveRecord::Migration[8.1]
  def up
    change_column_null :people, :user_id, false
    change_column_null :events, :user_id, false
  end

  def down
    change_column_null :people, :user_id, true
    change_column_null :events, :user_id, true
  end
end
