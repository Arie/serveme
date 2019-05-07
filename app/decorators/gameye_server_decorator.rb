# frozen_string_literal: true
class GameyeServerDecorator < ServerDecorator
  def flag
    if location_flag
      tag.span "", class: "flags flags-#{location_flag}", title: location_name
    else
      ""
    end
  end

  def location_name
    if reservation && reservation.gameye_location
      locations[reservation.gameye_location][:name]
    end
  end

  def location_flag
    if reservation && reservation.gameye_location
      locations[reservation.gameye_location][:flag]
    end
  end

  def locations
    { "londen" => {name: "London", flag: "en"},
      "frankfurt" => {name: "Frankfurt", flag: "de"} }
  end

end
