class CreateGroupServers < ActiveRecord::Migration
  def up
    create_table :group_servers do |t|
      t.integer :server_id
      t.integer :group_id
      t.timestamps
    end
  end

  def down
    drop_table :group_servers
  end
end
