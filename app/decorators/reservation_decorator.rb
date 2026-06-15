# typed: true
# frozen_string_literal: true

class ReservationDecorator < Draper::Decorator
  extend T::Sig
  include Draper::LazyHelpers
  delegate_all

  sig { returns(String) }
  def server_name
    server = object.server
    (server && (flag + server.name)) || "Unknown server"
  end

  sig { returns(String) }
  def flag
    abbreviation = server_location_flag
    location_name = server_location
    h.tag.span "", class: "flags flags-#{abbreviation}", title: location_name
  end

  sig { returns(T.nilable(String)) }
  def server_location_name
    server_location&.name
  end

  sig { returns(T.nilable(String)) }
  def server_location_flag
    server_location&.flag
  end

  sig { returns(T.nilable(Location)) }
  def server_location
    @server_location ||= object.server&.location
  end
end
