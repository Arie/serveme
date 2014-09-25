class CreateServerStatistics < ActiveRecord::Migration
  def change
    create_table :server_statistics do |t|
      t.integer :server_id,         null: false
      t.integer :reservation_id,    null: false
      t.integer :cpu_usage
      t.integer :fps
      t.integer :number_of_players
      t.string  :map_name,          limit: 191
      t.integer :traffic_in
      t.integer :traffic_out
      t.timestamps
    end
    add_index :server_statistics, :server_id
    add_index :server_statistics, :reservation_id
    add_index :server_statistics, :cpu_usage
    add_index :server_statistics, :fps
    add_index :server_statistics, :number_of_players
  end
end
