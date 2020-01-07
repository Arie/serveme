# frozen_string_literal: true

class PlayerStatisticDecorator < Draper::Decorator
  include Draper::LazyHelpers
  delegate_all

  def name
    if flag
      flag + reservation_player.name
    else
      reservation_player.name
    end
  end

  def flag
    geocoded && h.content_tag(:span, '', class: "flags flags-#{flag_abbreviation}", title: geocoded.country)
  end

  def flag_abbreviation
    geocoded.country_code.downcase
  end

  def maps_link
    if reservation_player.latitude
      distance = reservation_player.server.distance_to(reservation_player.to_coordinates).to_f.round
      coords = reservation_player.to_coordinates
      link_to distance, "http://maps.google.com/maps?q=#{coords.first},#{coords.last}+(Player)&z=4&ll=#{coords.first},#{coords.last}"
    end
  end

  def geocoded
    @geocoded ||= Geocoder.search(reservation_player.ip).try(:first)
  end
end
