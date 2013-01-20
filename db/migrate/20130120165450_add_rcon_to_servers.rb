class AddRconToServers < ActiveRecord::Migration
  def change
    add_column :servers, :rcon, :string
  end
end
