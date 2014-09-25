class AddLatLongToServers < ActiveRecord::Migration
  def change
    add_column :servers, :latitude, :float
    add_column :servers, :longitude, :float
  end
end
