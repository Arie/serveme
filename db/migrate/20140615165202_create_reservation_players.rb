class CreateReservationPlayers < ActiveRecord::Migration
  def change
    create_table :reservation_players do |t|
      t.integer :reservation_id
      t.string :steam_uid, :limit => 191
    end
    add_index :reservation_players, :reservation_id
    add_index :reservation_players, :steam_uid
  end
end
