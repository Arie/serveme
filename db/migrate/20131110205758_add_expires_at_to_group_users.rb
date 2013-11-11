class AddExpiresAtToGroupUsers < ActiveRecord::Migration
  def up
    add_column :group_users, :expires_at, :datetime
    add_index :group_users, :expires_at
    GroupUser.reset_column_information
    GroupUser.where(:group_id => Group.donator_group).update_all(:expires_at => 1.year.from_now)
  end

  def down
    remove_column :group_users, :expires_at
  end
end
