# frozen_string_literal: true

class ReservationDecorator < Draper::Decorator
  include Draper::LazyHelpers
  delegate_all

  def server_name
    flag + server.name
  end

  def flag
    abbreviation = server_location_flag
    location_name = server_location
    tag.span '', class: "flags flags-#{abbreviation}", title: location_name
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
