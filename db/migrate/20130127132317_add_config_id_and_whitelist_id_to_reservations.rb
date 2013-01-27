class AddConfigIdAndWhitelistIdToReservations < ActiveRecord::Migration
  def up
    add_column :reservations, :server_config_id, :integer
    add_column :reservations, :whitelist_id, :integer

    add_index :reservations,  :server_config_id
    add_index :reservations,  :whitelist_id
  end

  def down
    remove_index :reservations, :column => :whitelist_id
    remove_index :reservations, :column => :server_config_id

    remove_column :reservations, :whitelist_id
    remove_column :reservations, :server_config_id
  end
end
