class NormalizePlayerStatistics < ActiveRecord::Migration
  def change
    add_column :reservation_players, :name,   :string, :limit => 191
    add_column :reservation_players, :ip,     :string, :limit => 191
    add_column :reservation_players, :latitude, :float
    add_column :reservation_players, :longitude, :float
    add_index :reservation_players, [:latitude, :longitude]

    remove_column :player_statistics, :name
    remove_column :player_statistics, :steam_uid
    remove_column :player_statistics, :reservation_id
    remove_column :player_statistics, :server_id
    remove_column :player_statistics, :ip
    remove_column :player_statistics, :latitude
    remove_column :player_statistics, :longitude
    add_column :player_statistics, :reservation_player_id, :integer
    add_index :player_statistics, :reservation_player_id
  end
end
