class AddCompositeIndexToReservationPlayers < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :reservation_players, [ :steam_uid, :reservation_id ], algorithm: :concurrently, if_not_exists: true
  end
end
