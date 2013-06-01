class AddLastNumberOfPlayersToReservations < ActiveRecord::Migration
  def change
    add_column :reservations, :last_number_of_players, :integer, :default => 0
  end
end
