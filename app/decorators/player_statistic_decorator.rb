class PlayerStatisticDecorator < Draper::Decorator
  include Draper::LazyHelpers
  delegate_all

  def name
    flag + source.name
  end

  def flag
    h.content_tag(:span, "", :class => "flags flags-#{flag_abbreviation}", :title => geocoded.country)
  end

  def flag_abbreviation
    geocoded.country_code.downcase
  end

  def maps_link
    if player_statistic.latitude
      distance = player_statistic.server.distance_to(player_statistic.to_coordinates).to_f.round
      coords = player_statistic.to_coordinates
      link_to distance, "http://maps.google.com/maps?q=#{coords.first},#{coords.last}+(Player)&z=4&ll=#{coords.first},#{coords.last}"
    end
  end

  def geocoded
    @geocoded ||= Geocoder.search(ip).try(:first)
  end

end
