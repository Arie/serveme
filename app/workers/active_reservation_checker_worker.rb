# frozen_string_literal: true
class ActiveReservationCheckerWorker
  include Sidekiq::Worker

  sidekiq_options :retry => 1

  def perform(reservation_id)
    reservation = Reservation.find(reservation_id)
    server = reservation.server

    if server
      server_info = reservation.server.server_info
      begin
        server_info.status
        server_info.get_stats
        server_info.get_rcon_status
        ServerMetric.new(server_info)
        server.rcon_exec "sv_logsecret #{reservation.logsecret}"
      rescue SteamCondenser::Error, Errno::ECONNREFUSED
        Rails.logger.warn "Couldn't update #{reservation.server.name}"
      end

      if reservation.server.occupied?
        reservation.update_column(:last_number_of_players, server_info.number_of_players)
        reservation.update_column(:inactive_minute_counter, 0)
        reservation.warn_nearly_over if reservation.nearly_over?
        reservation.apply_api_keys if reservation.enable_demos_tf?
      else
        previous_number_of_players = reservation.last_number_of_players.to_i
        reservation.update_column(:last_number_of_players, 0)
        reservation.increment!(:inactive_minute_counter)
        if previous_number_of_players > 0 && (reservation.starts_at < 30.minutes.ago) && (reservation.auto_end?)
          Rails.logger.warn "Automatically ending #{reservation} because it went from occupied to empty"
          reservation.end_reservation
        end
      end
    end
  end
end
