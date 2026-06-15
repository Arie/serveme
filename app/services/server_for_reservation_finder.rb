# typed: strict
# frozen_string_literal: true

class ServerForReservationFinder
  extend T::Sig

  sig { returns(Reservation) }
  attr_reader :reservation

  sig { params(reservation: Reservation).void }
  def initialize(reservation)
    @reservation = reservation
  end

  sig { returns(ActiveRecord::Relation) }
  def servers
    colliding_reservations = CollisionFinder.new(Reservation.where(server_id: available_for_user), reservation).colliding_reservations
    if colliding_reservations.any?
      available_for_user.where("id NOT IN (?)", colliding_reservations.map(&:server_id))
    else
      available_for_user
    end
  end

  sig { returns(ActiveRecord::Relation) }
  def available_for_user
    Server.includes(:location).active.updated.reservable_by_user(reservation.user)
  end
end
