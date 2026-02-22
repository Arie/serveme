class AddIndexOnCloudStatusToServers < ActiveRecord::Migration[8.1]
  def change
    add_index :servers, :cloud_status
  end
end
