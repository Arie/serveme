# typed: true
# frozen_string_literal: true

class PlayerStatisticDecorator < Draper::Decorator
  extend T::Sig
  include Draper::LazyHelpers
  delegate_all

  sig { returns(T.nilable(String)) }
  def name
    flag_html = flag
    if flag_html
      flag_html + object.reservation_player.name
    else
      object.reservation_player.name
    end
  end

  sig { returns(T.nilable(ActiveSupport::SafeBuffer)) }
  def flag
    geocoded && h.content_tag(:span, "", class: "flags flags-#{flag_abbreviation}", title: geocoded.country)
  end

  sig { returns(String) }
  def flag_abbreviation
    geocoded.country_code.downcase
  end

  sig { returns(T.nilable(String)) }
  def maps_link
    reservation_player = object.reservation_player
    return unless reservation_player.latitude

    distance = reservation_player.server.distance_to(reservation_player.to_coordinates).to_f.round
    coords = reservation_player.to_coordinates
    h.link_to distance, "http://maps.google.com/maps?q=#{coords.first},#{coords.last}+(Player)&z=4&ll=#{coords.first},#{coords.last}"
  end

  sig { returns(T.untyped) }
  def geocoded
    @geocoded ||= context[:geocoded]&.dig(object.reservation_player.ip) || Geocoder.search(object.reservation_player.ip).try(:first)
  end
end
