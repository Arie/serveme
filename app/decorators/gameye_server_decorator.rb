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
    {
      "amsterdam"     => {name: "Amsterdam",        flag: "nl"},
      "chicago"       => {name: "Chicago",          flag: "us"},
      "frankfurt"     => {name: "Frankfurt",        flag: "de"},
      "london"        => {name: "London",           flag: "en"},
      "moscow"        => {name: "Moscow",           flag: "ru"},
      "new_york"      => {name: "New York",         flag: "us"},
      "phoenix"       => {name: "Phoenix",          flag: "us"},
      "san_francisco" => {name: "San Francisco",    flag: "us"},
      "sao_paulo"     => {name: "São Paulo",        flag: "br"},
      "warsaw"        => {name: "Warsaw",           flag: "pl"},
      "washington_dc" => {name: "Washington D.C.",  flag: "us"}
    }
  end

end
