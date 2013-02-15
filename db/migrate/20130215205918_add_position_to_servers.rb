class AddPositionToServers < ActiveRecord::Migration
  def change
    add_column :servers, :position, :integer, :default => 1000
  end
end
