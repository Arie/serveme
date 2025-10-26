# typed: false
# frozen_string_literal: true

class CheckSdrSteamProfileWorker
  include Sidekiq::Worker

  sidekiq_options retry: false, queue: "default"

  def perform(reservation_player_id)
    rp = ReservationPlayer.find_by(id: reservation_player_id)
    return unless rp

    reservation = rp.reservation
    return unless reservation
    return if reservation.ended?

    unless ReservationPlayer.sdr_eligible_steam_profile?(rp.steam_uid.to_i)
      server_info = reservation.server&.server_info
      return unless server_info

      begin
        parser = RconStatusParser.new(server_info.fetch_rcon_status)
        player = parser.players.find { |p| p.steam_uid == rp.steam_uid.to_i && p.ip == rp.ip }

        if player
          reservation.server&.rcon_exec "kickid #{player.user_id} SDR requires public Steam profile 6+ months old; addip 1 #{rp.ip}"
          Rails.logger.info "Kicked SDR player #{rp.name} (#{rp.steam_uid}) - ineligible Steam profile - Reservation ##{reservation.id}"

          rp.update(whitelisted: false)
        end
      rescue SteamCondenser::Error => e
        Rails.logger.warn "Failed to kick SDR player #{rp.steam_uid} - Reservation ##{reservation.id}: #{e.message}"
      end
    end
  end
end
