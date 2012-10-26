class CreateGroupUsers < ActiveRecord::Migration
  def up
    create_table :group_users do |t|
      t.integer :user_id
      t.integer :group_id
      t.timestamps
    end
  end

  def down
    drop_table :group_users
  end
end
