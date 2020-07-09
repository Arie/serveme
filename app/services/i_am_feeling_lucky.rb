# frozen_string_literal: true

class IAmFeelingLucky
  attr_accessor :user

  def initialize(user)
    @user = user
  end

  def build_reservation
    new_reservation_attributes = { starts_at: starts_at,
                                   ends_at: ends_at }
    user.reservations.build(base_attributes.merge(new_reservation_attributes))
  end

  def base_attributes
    if previous_reservation
      previous_reservation.reusable_attributes.merge('server' => best_matching_server)
    else
      new_reservation_attributes
    end
  end

  def new_reservation_attributes
    {
      'rcon' => rand(10**5),
      'password' => rand(10**5),
      'tv_password' => rand(10**5),
      'auto_end' => true,
      'server' => first_available_server
    }
  end

  def previous_reservation
    @previous_reservation ||= user.reservations.joins(:server).where("servers.type != 'Gameye'").where('reservations.ends_at < ?', Time.current).last
  end

  def previous_server
    @previous_server ||= previous_reservation.server
  end

  def best_matching_server
    if available_server_on_previous_host
      available_server_on_previous_host
    elsif available_server_in_same_location
      available_server_in_same_location
    else
      first_available_server
    end
  end

  def available_server_on_previous_host
    @available_server_on_previous_host ||= available_servers_on_previous_host.first
  end

  def available_servers_on_previous_host
    available_servers.where(ip: previous_server.ip)
  end

  def available_server_in_same_location
    @available_server_in_same_location ||= available_servers_in_same_location.first
  end

  def available_servers_in_same_location
    available_servers.where(location_id: previous_server.location_id)
  end

  def available_servers
    ServerForUserFinder.new(user, starts_at, ends_at).servers.ordered
  end

  def first_available_server
    available_servers.first
  end

  def starts_at
    Time.current
  end

  def ends_at
    2.hours.from_now
  end
end
