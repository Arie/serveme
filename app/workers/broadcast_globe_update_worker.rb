# typed: true
# frozen_string_literal: true

require File.expand_path("../models/concerns/steam_id_anonymizer", __dir__)

class BroadcastGlobeUpdateWorker
  include Sidekiq::Worker
  include SteamIdAnonymizer
  include GlobeData

  def perform
    # Get all servers with current players
    servers_with_players = CurrentPlayersService.all_servers_with_current_players

    all_server_data = globe_server_data(servers_with_players)

    globe_data = {
      servers: all_server_data.map { |data| server_globe_data(data[:server], data[:players]) }
    }

    Turbo::StreamsChannel.broadcast_replace_to(
      "player_globe_updates",
      target: "player_stats_update",
      partial: "players/globe_stats_update",
      locals: { globe_json_data: globe_data }
    )
  end

  private

  def server_globe_data(server, players)
    {
      id: server.id,
      name: server.name,
      latitude: server.latitude,
      longitude: server.longitude,
      location: server.detailed_location,
      slots: server.respond_to?(:max_containers) ? server.max_containers : 1,
      active_slots: server.respond_to?(:active_containers) ? server.active_containers : (players.any? ? 1 : 0),
      players: players.map do |player|
        {
          steam_uid: anonymize_steam_id(player[:reservation_player].steam_uid.to_s),
          latitude: player[:player_latitude],
          longitude: player[:player_longitude],
          country_code: player[:country_code],
          country_name: player[:country_name],
          city_name: player[:city_name],
          distance: player[:distance],
          ping: player[:player_statistic].ping,
          loss: player[:player_statistic].loss,
          minutes_connected: player[:player_statistic].minutes_connected
        }
      end
    }
  end
end
