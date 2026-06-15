# typed: true
# frozen_string_literal: true

class ServerForUserFinder
  extend T::Sig

  attr_reader :user, :starts_at, :ends_at

  sig { params(user: T.untyped, starts_at: T.untyped, ends_at: T.untyped).void }
  def initialize(user, starts_at, ends_at)
    @user                       = user
    @starts_at                  = starts_at
    @ends_at                    = ends_at
  end

  sig { returns(ActiveRecord::Relation) }
  def servers
    if (ends_at.to_i - starts_at.to_i).between?(60, 36_000)
      available_for_user = Server.includes(:location).active.updated.reservable_by_user(user)
      colliding_reservations = CollisionFinder.new(Reservation.where(server_id: available_for_user), reservation).colliding_reservations
      if colliding_reservations.any?
        available_for_user.where("servers.id NOT IN (?)", colliding_reservations.map(&:server_id))
      else
        available_for_user
      end
    else
      Server.none
    end
  end

  private

  sig { returns(Reservation) }
  def reservation
    @reservation ||= Reservation.new(starts_at: starts_at, ends_at: ends_at, user_id: user.id)
  end
end
