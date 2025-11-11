class AddSteamUidIpIndexToReservationPlayers < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # Add composite index for steam_uid and ip to speed up cross-reference queries
    # Partial index excludes SDR IPs (169.254.x.x) which are not useful for league requests
    add_index :reservation_players,
              [ :steam_uid, :ip ],
              where: "ip NOT LIKE '169.254.%'",
              name: 'index_reservation_players_on_steam_uid_ip_no_sdr',
              algorithm: :concurrently
  end
end
