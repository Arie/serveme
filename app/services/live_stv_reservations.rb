# typed: true
# frozen_string_literal: true

class LiveStvReservations
  extend T::Sig

  Player = Struct.new(:name, :steam_uid, :country_code, keyword_init: true)
  Row = Struct.new(:reservation, :map, :players, keyword_init: true)

  sig { returns(T::Array[Row]) }
  def self.rows
    reservations = Reservation.current.joins(:server).where(servers: { sdr: [ false, nil ] })
                              .preload(:user, :server_config, :whitelist, server: :location)
                              .select(&:stv_watchable?)
    maps = latest_maps(reservations.map(&:id))
    players = players_by_reservation

    rows = reservations.map do |r|
      Row.new(reservation: r, map: maps[r.id] || r.first_map, players: players.fetch(r.id, []))
    end
    rows.sort_by { |row| [ -row.players.size, row.reservation.starts_at ] }
  end

  sig { params(ids: T::Array[Integer]).returns(T::Hash[Integer, T.nilable(String)]) }
  def self.latest_maps(ids)
    ServerStatistic.where(reservation_id: ids, created_at: 5.minutes.ago..)
                   .select("DISTINCT ON (reservation_id) reservation_id, map_name")
                   .order(:reservation_id, created_at: :desc)
                   .to_h { |s| [ s.reservation_id, s.map_name ] }
  end

  sig { returns(T::Hash[Integer, T::Array[Player]]) }
  def self.players_by_reservation
    CurrentPlayersService.cached_servers_with_current_players.each_with_object({}) do |server_data, by_reservation|
      server_data[:players].each do |player|
        reservation_player = player[:reservation_player]
        next unless reservation_player&.reservation_id

        (by_reservation[reservation_player.reservation_id] ||= []) <<
          Player.new(name: reservation_player.name, steam_uid: reservation_player.steam_uid, country_code: player[:country_code])
      end
    end
  end
  private_class_method :latest_maps, :players_by_reservation
end
