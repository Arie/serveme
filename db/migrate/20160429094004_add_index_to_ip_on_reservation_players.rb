class AddIndexToIpOnReservationPlayers < ActiveRecord::Migration
  def change
    add_index :reservation_players, :ip
  end
end
