class AddCustomWhitelistIdToReservations < ActiveRecord::Migration
  def change
    add_column :reservations, :custom_whitelist_id, :integer
    add_index :reservations, :custom_whitelist_id
  end
end
