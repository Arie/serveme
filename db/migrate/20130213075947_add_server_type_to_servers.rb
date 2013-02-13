class AddServerTypeToServers < ActiveRecord::Migration
  def change
    add_column :servers, :server_type, :string, :default => "local"
  end
end
