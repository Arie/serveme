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
    Server.active.reservable_by_user(user)
  end

  def self.grouped_available_for_user(user)
    grouped_for_user(user, available_for_user(user))
  end

  def self.grouped_for_user(user, servers)
    grouped_servers = []
    user.groups.each do |group|
      grouped_servers << {:name => group.name, :servers => servers.in_groups([group]).ordered}
    end

    free_servers = servers.without_group.ordered
    grouped_servers << {:name => "Everyone", :servers => free_servers}
  end

  private

  def reservation
    @reservation ||= Reservation.new(:starts_at => starts_at, :ends_at => ends_at, :user_id => user.id)
  end

end
