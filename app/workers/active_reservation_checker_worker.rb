# frozen_string_literal: true
class ActiveReservationCheckerWorker
  include Sidekiq::Worker

  sidekiq_options :retry => 1

  def perform(reservation_id)
    reservation = Reservation.find(reservation_id)

    server_info = reservation.server.server_info
    begin
      server_info.status
      server_info.get_stats
      server_info.get_rcon_status
      if reservation.gameye?
        reservation.server.rcon_exec "sv_logsecret #{reservation.logsecret}"
      end
      ServerMetric.new(server_info)
    rescue SteamCondenser::Error, Errno::ECONNREFUSED
      Rails.logger.warn "Couldn't update #{reservation.server.name}"
    end

    if reservation.server.occupied?
      reservation.update_column(:last_number_of_players, server_info.number_of_players)
      reservation.update_column(:inactive_minute_counter, 0)
      reservation.warn_nearly_over if reservation.nearly_over?
    else
      previous_number_of_players = reservation.last_number_of_players.to_i
      reservation.update_column(:last_number_of_players, 0)
      reservation.increment!(:inactive_minute_counter)
      if reservation.inactive_too_long? && !reservation.lobby?
        reservation.user.increment!(:expired_reservations)
        reservation.update_attribute(:end_instantly, true)
        reservation.end_reservation
      elsif previous_number_of_players > 0 && (reservation.starts_at < 30.minutes.ago) && (reservation.auto_end?)
        Rails.logger.warn "Automatically ending #{reservation} because it went from occupied to empty"
        reservation.end_reservation
      end
    end
  end

end
