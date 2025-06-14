class AddResolvedIpToServers < ActiveRecord::Migration[7.0]
  def change
    add_column :servers, :resolved_ip, :string
    add_index :servers, :resolved_ip
  end
end
