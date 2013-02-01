class FreeServerFinder

  attr_reader :servers_available_for_user, :starts_at, :ends_at

  def initialize(servers_available_for_user, starts_at, ends_at)
    @servers_available_for_user = servers_available_for_user
    @starts_at                  = starts_at
    @ends_at                    = ends_at
  end

  def servers
    servers_available_for_user.select do |server|
      CollisionFinder.new(server, reservation).colliding_reservations.none?
    end
  end

  def user_already_reserved_a_server_in_range?(user, starts_at, ends_at)
    CollisionFinder.new(user, reservation).colliding_reservations.any?
  end

  private

  def reservation
    @reservation ||= Reservation.new(:starts_at => starts_at, :ends_at => ends_at)
  end

end
