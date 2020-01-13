# frozen_string_literal: true

class ReservationDecorator < Draper::Decorator
  include Draper::LazyHelpers
  delegate_all

  def server_name
    if gameye? && !server
      flag + "Gameye #{gameye_location_name}"
    else
      flag + server.name
    end
  end

  def flag
    abbreviation = server_location_flag || gameye_location_flag
    location_name = server_location || gameye_location
    tag.span '', class: "flags flags-#{abbreviation}", title: location_name
  end

  def gameye_location_flag
    gameye_location_info && gameye_location_info[:flag]
  end

  def gameye_location_name
    gameye_location_info && gameye_location_info[:name]
  end

  def gameye_location_info
    @gameye_location_info ||= gameye_locations.find do |loc|
      loc[:id] == gameye_location
    end
  end

  def gameye_locations
    GameyeServer.locations
  end

  def server_location_name
    server_location&.name
  end

  def server_location_flag
    server_location&.flag
  end

  def server_location
    @server_location ||= server&.location
  end
end
