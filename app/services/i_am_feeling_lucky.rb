# typed: true
# frozen_string_literal: true

class IAmFeelingLucky
  extend T::Sig

  sig { returns(User) }
  attr_accessor :user

  sig { params(user: User).void }
  def initialize(user)
    @user = user
  end

  sig { returns(Reservation) }
  def build_reservation
    new_reservation_attributes = {
      starts_at: starts_at,
      ends_at: ends_at
    }
    user.reservations.build(base_attributes.merge(new_reservation_attributes))
  end

  sig { returns(T::Hash[String, T.untyped]) }
  def base_attributes
    prev = previous_reservation
    if prev
      prev.reusable_attributes.merge("server" => best_matching_server, "enable_plugins" => prev.enable_plugins?)
    else
      new_reservation_attributes
    end
  end

  sig { returns(T::Hash[String, T.untyped]) }
  def new_reservation_attributes
    {
      "rcon" => rand(10**5).to_s,
      "password" => rand(10**5).to_s,
      "tv_password" => rand(10**5).to_s,
      "auto_end" => true,
      "server" => first_available_server
    }
  end

  sig { returns(T.nilable(Reservation)) }
  def previous_reservation
    @previous_reservation ||= user.reservations.joins(:server).where(ends_at: ...Time.current).last
  end

  sig { returns(Server) }
  def previous_server
    @previous_server ||= T.must(T.must(previous_reservation).server)
  end

  sig { returns(T.nilable(Server)) }
  def best_matching_server
    if available_server_on_previous_host
      available_server_on_previous_host
    elsif available_server_in_same_location
      available_server_in_same_location
    else
      first_available_server
    end
  end

  sig { returns(T.nilable(Server)) }
  def available_server_on_previous_host
    @available_server_on_previous_host ||= available_servers_on_previous_host.first
  end

  sig { returns(ActiveRecord::Relation) }
  def available_servers_on_previous_host
    available_servers.where(ip: previous_server.host_hostname)
  end

  sig { returns(T.nilable(Server)) }
  def available_server_in_same_location
    @available_server_in_same_location ||= available_servers_in_same_location.first
  end

  sig { returns(ActiveRecord::Relation) }
  def available_servers_in_same_location
    available_servers.where(location_id: previous_server.location_id)
  end

  sig { returns(ActiveRecord::Relation) }
  def available_servers
    ServerForUserFinder.new(user, starts_at, ends_at).servers.order(:position, :name)
  end

  sig { returns(T.nilable(Server)) }
  def first_available_server
    available_servers.first
  end

  # Remote-docker fallback: when no regular server is free, pick a docker host
  # with spare capacity, with the same affinity as best_matching_server.
  # Returns nil when none.
  sig { returns(T.nilable(DockerHost)) }
  def available_docker_host
    @available_docker_host ||= best_matching_docker_host(DockerHost.available_during(starts_at, ends_at))
  end

  # Prefer a docker host running on the same machine as the user's previous
  # server (matched by hostname), then one in the same location, then any.
  sig { params(hosts: T.untyped).returns(T.nilable(DockerHost)) }
  def best_matching_docker_host(hosts)
    return hosts.first unless previous_reservation

    docker_host_on_previous_host(hosts) || docker_host_in_previous_location(hosts) || hosts.first
  end

  sig { params(hosts: T.untyped).returns(T.nilable(DockerHost)) }
  def docker_host_on_previous_host(hosts)
    hostname = previous_server.host_hostname
    hosts.find { |host| host.hostname == hostname }
  end

  # Attributes for DockerHostReservationCreator, reusing the same settings the
  # regular lucky reservation would have gotten, minus the server reference.
  sig { returns(ActiveSupport::HashWithIndifferentAccess) }
  def docker_host_reservation_params
    base_attributes.except("server", "server_id").merge(
      "starts_at" => starts_at,
      "ends_at" => ends_at
    ).with_indifferent_access
  end

  sig { params(hosts: T.untyped).returns(T.nilable(DockerHost)) }
  def docker_host_in_previous_location(hosts)
    hosts.find { |host| host.location_id == previous_server.location_id }
  end

  sig { returns(ActiveSupport::TimeWithZone) }
  def starts_at
    Time.current
  end

  sig { returns(ActiveSupport::TimeWithZone) }
  def ends_at
    2.hours.from_now
  end
end
