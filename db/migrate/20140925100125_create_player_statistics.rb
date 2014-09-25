class CreatePlayerStatistics < ActiveRecord::Migration
  def change
    create_table :player_statistics do |t|
      t.integer :server_id,       null: false
      t.integer :reservation_id,  null: false
      t.string  :name,       limit: 191
      t.string  :steam_uid,  limit: 191
      t.integer :ping
      t.integer :loss
      t.integer :minutes_connected
      t.timestamps
    end
    add_index :player_statistics, :server_id
    add_index :player_statistics, :reservation_id
    add_index :player_statistics, :steam_uid
    add_index :player_statistics, :ping
    add_index :player_statistics, :loss
  end
end
