# frozen_string_literal: true
class ServerForReservationFinder

  attr_reader :reservation

  def initialize(reservation)
    @reservation = reservation
  end

  def servers
    colliding_reservations = CollisionFinder.new(Reservation.where(:server_id => available_for_user), reservation).colliding_reservations
    if colliding_reservations.any?
      available_for_user.where('id NOT IN (?)', colliding_reservations.map(&:server_id))
    else
      available_for_user
    end
  end

  def available_for_user
    Server.includes(:location).active.reservable_by_user(reservation.user)
  end

end
