class ServerFinder

  attr_reader :user, :starts_at, :ends_at

  def initialize(user, starts_at, ends_at)
    @user                       = user
    @starts_at                  = starts_at
    @ends_at                    = ends_at
  end

  def servers
    ServerFinder.available_for_user(user).select do |server|
      CollisionFinder.new(server, reservation).colliding_reservations.none?
    end
  end

  def user_already_reserved_a_server_in_range?
    CollisionFinder.new(user, reservation).colliding_reservations.any?
  end

  def self.available_for_user(user)
    Server.reservable_by_user(user).order('servers.position ASC')
  end

  private

  def reservation
    @reservation ||= Reservation.new(:starts_at => starts_at, :ends_at => ends_at, :user_id => user.id)
  end

end
