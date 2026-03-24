# typed: false
# frozen_string_literal: true

class ScoreboardConnectionInfo
  def self.for_reservation(reservation)
    result = from_reservation_players(reservation)
    merge_player_statistics!(result, reservation)
    result
  end

  def self.from_reservation_players(reservation)
    result = {}

    reservation.reservation_players.each do |rp|
      location = CurrentPlayersService.get_player_location_info(rp)
      result[rp.steam_uid] = {
        ping: nil,
        loss: nil,
        country_code: location[:country_code],
        country_name: location[:country_name],
        distance: location[:distance],
        distance_unit: CurrentPlayersService.distance_unit_for_region,
        sdr: location[:sdr],
        asn_organization: rp.asn_organization
      }
    end

    result
  end

  def self.merge_player_statistics!(result, reservation)
    latest_stats = PlayerStatistic
      .select("DISTINCT ON (reservation_players.steam_uid) player_statistics.*, reservation_players.steam_uid AS rp_steam_uid")
      .joins(:reservation_player)
      .where(reservation_players: { reservation_id: reservation.id })
      .order("reservation_players.steam_uid, player_statistics.created_at DESC")

    latest_stats.each do |stat|
      uid = stat.rp_steam_uid
      if result[uid]
        result[uid][:ping] = stat.ping
        result[uid][:loss] = stat.loss
      end
    end
  end
end
