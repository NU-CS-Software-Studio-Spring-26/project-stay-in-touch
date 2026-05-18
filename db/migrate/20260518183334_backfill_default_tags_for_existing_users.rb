class BackfillDefaultTagsForExistingUsers < ActiveRecord::Migration[8.1]
  def up
    default_tags = %w[Work Family Friends]
    User.find_each do |user|
      default_tags.each do |name|
        user.tags.find_or_create_by!(name: name)
      end
    end
  end

  def down
    # no-op — removing seeded tags is destructive and would break associations
  end
end
