class AddCloudColumnsToServers < ActiveRecord::Migration[8.1]
  def change
    add_column :servers, :cloud_provider, :string
    add_column :servers, :cloud_provider_id, :string
    add_column :servers, :cloud_status, :string
    add_column :servers, :cloud_location, :string
    add_column :servers, :cloud_reservation_id, :bigint
    add_column :servers, :cloud_created_at, :datetime
    add_column :servers, :cloud_destroyed_at, :datetime
    add_index  :servers, :cloud_reservation_id
  end
end
