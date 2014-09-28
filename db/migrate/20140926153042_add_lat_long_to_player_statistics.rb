class AddLatLongToPlayerStatistics < ActiveRecord::Migration
  def change
    add_column :player_statistics, :latitude, :float
    add_column :player_statistics, :longitude, :float
    add_index :player_statistics, [:latitude, :longitude]
  end
end
