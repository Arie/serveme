# typed: false
# frozen_string_literal: true

class ScoreboardConnectionInfo
  def self.for_reservation(reservation)
    recent_stats = PlayerStatistic.joins(:reservation_player)
                                  .where(reservation_players: { reservation_id: reservation.id })
                                  .where("player_statistics.created_at >= ?", 90.seconds.ago)
                                  .includes(:reservation_player)
                                  .order("player_statistics.created_at DESC")

    result = {}
    seen = Set.new

    recent_stats.each do |stat|
      rp = stat.reservation_player
      next if seen.include?(rp.steam_uid)

      seen << rp.steam_uid

      location = CurrentPlayersService.get_player_location_info(rp)
      result[rp.steam_uid] = {
        ping: stat.ping,
        loss: stat.loss,
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
end
