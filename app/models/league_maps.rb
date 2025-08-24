# typed: true
# frozen_string_literal: true

class LeagueMaps
  extend T::Sig

  attr_accessor :name, :maps

  def initialize(name:, maps:)
    @name = name
    @maps = maps
  end

  sig { returns(T::Array[LeagueMaps]) }
  def self.all
    grouped_league_maps + [ new(name: "All maps", maps: MapUpload.available_maps) ]
  end

  sig { returns(T::Array[LeagueMaps]) }
  def self.grouped_league_maps
    config_data = load_config_data
    league_maps_data = config_data.dig("league_maps") || []

    league_maps_data
      .select { |league| league["active"] != false }
      .map { |league| new(name: league["name"], maps: (league["maps"] || []).uniq.sort) }
  end

  def self.all_league_maps
    grouped_league_maps.flat_map(&:maps).uniq.sort
  end


  private

  sig { returns(T::Hash[String, T.untyped]) }
  def self.load_config_data
    service = LeagueMapsSyncService.new
    service.current_config
  end
end
