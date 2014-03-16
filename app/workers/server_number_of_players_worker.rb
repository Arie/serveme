class ServerNumberOfPlayersWorker
  include Sidekiq::Worker

  sidekiq_options :retry => 1

  def perform(reservation_id)
    reservation = Reservation.find(reservation_id)
    if reservation.server.occupied?
      reservation.update_column(:last_number_of_players, reservation.server.number_of_players)
      reservation.update_column(:inactive_minute_counter, 0)
      reservation.warn_nearly_over if reservation.nearly_over?
    else
      previous_number_of_players = reservation.last_number_of_players.to_i
      reservation.update_column(:last_number_of_players, 0)
      reservation.increment!(:inactive_minute_counter)
      if reservation.inactive_too_long?
        reservation.end_reservation
      elsif previous_number_of_players > 0 && (reservation.starts_at < 30.minutes.ago) && (reservation.auto_end?)
        Rails.logger.info "Automatically ended #{reservation} because it went from occupied to empty"
        reservation.end_reservation
      end
    end
  end

end
