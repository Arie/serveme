class AddWhitelistedToReservationPlayers < ActiveRecord::Migration[6.1]
  def change
    add_column :reservation_players, :whitelisted, :boolean
  end
end
