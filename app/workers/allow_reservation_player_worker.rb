# frozen_string_literal: true

class AllowReservationPlayerWorker
  include Sidekiq::Worker

  sidekiq_options retry: 10

  def perform(reservation_player_id)
    reservation_player = ReservationPlayer.includes(reservation: :server).find(reservation_player_id)
    reservation = reservation_player.reservation
    reservation.allow_reservation_player(reservation_player) unless reservation.ended?
  end
end
