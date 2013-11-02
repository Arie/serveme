class ServerFinder

  attr_reader :user, :starts_at, :ends_at

  def initialize(user, starts_at, ends_at)
    @user                       = user
    @starts_at                  = starts_at
    @ends_at                    = ends_at
  end

  def servers
    Server.active.reservable_by_user(user).select do |server|
      CollisionFinder.new(server, reservation).colliding_reservations.none?
    end
  end

  def user_already_reserved_a_server_in_range?
    CollisionFinder.new(user, reservation).colliding_reservations.any?
  end

  def self.available_for_user(user)
    servers = []
    user.groups.each do |group|
      servers << {:name => group.name, :servers => Server.active.reservable_by_user(user).in_groups([group])}
    end

    free_servers = Server.active.reservable_by_user(user).without_group.ordered
    servers << {:name => "Everyone", :servers => free_servers}
  end

  private

  def reservation
    @reservation ||= Reservation.new(:starts_at => starts_at, :ends_at => ends_at, :user_id => user.id)
  end

end
