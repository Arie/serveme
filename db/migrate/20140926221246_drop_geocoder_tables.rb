class DropGeocoderTables < ActiveRecord::Migration
  def change
    drop_table :maxmind_geolite_city_blocks
    drop_table :maxmind_geolite_city_location
  end
end
