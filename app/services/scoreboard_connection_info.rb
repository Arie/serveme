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
    latest_stats = PlayerStatistic.joins(:reservation_player)
                                  .where(reservation_players: { reservation_id: reservation.id })
                                  .includes(:reservation_player)
                                  .order("player_statistics.created_at DESC")

    seen = Set.new

    latest_stats.each do |stat|
      rp = stat.reservation_player
      next if seen.include?(rp.steam_uid)

      seen << rp.steam_uid

      if result[rp.steam_uid]
        result[rp.steam_uid][:ping] = stat.ping
        result[rp.steam_uid][:loss] = stat.loss
      end
    end
  end
end
