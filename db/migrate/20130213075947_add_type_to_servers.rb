class AddTypeToServers < ActiveRecord::Migration
  def change
    add_column :servers, :type, :string, :default => "LocalServer"
  end
end
