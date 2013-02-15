class FreeServerFinder

  attr_reader :user, :starts_at, :ends_at

  def initialize(user, starts_at, ends_at)
    @user                       = user
    @starts_at                  = starts_at
    @ends_at                    = ends_at
  end

  def servers
    servers_available_for_user.select do |server|
      CollisionFinder.new(server, reservation).colliding_reservations.none?
    end
  end

  def user_already_reserved_a_server_in_range?
    CollisionFinder.new(user, reservation).colliding_reservations.any?
  end

  private

  def servers_available_for_user
    @servers_available_for_user ||= Server.reservable_by_user(user).order('servers.position ASC')
  end

  def reservation
    @reservation ||= Reservation.new(:starts_at => starts_at, :ends_at => ends_at, :user_id => user.id)
  end

end
