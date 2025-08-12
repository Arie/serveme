# typed: false
# frozen_string_literal: true

class PlayersController < ApplicationController
  include SteamIdAnonymizer
  skip_before_action :authenticate_user!, only: [ :globe ]
  def index
    @servers_with_players = CurrentPlayersService.cached_servers_with_current_players
    @distance_unit = distance_unit

    if current_admin || current_league_admin || current_streamer
      render :admins
    else
      render :index
    end
  end

  def globe
    @servers_with_players = CurrentPlayersService.all_servers_with_current_players

    # Get all servers that have location data
    all_servers = Server.active.where.not(latitude: nil, longitude: nil)

    # Create a hash of servers with players for quick lookup
    servers_with_players_hash = @servers_with_players.to_h { |data| [ data[:server].id, data[:players] ] }

    # Combine all servers with their player data (empty array if no players)
    all_server_data = all_servers.map do |server|
      players = servers_with_players_hash[server.id] || []
      { server: server, players: players }
    end

    respond_to do |format|
      format.html
      format.json do
        render json: {
          servers: all_server_data.map { |data| server_globe_data(data[:server], data[:players]) }
        }
      end
    end
  end

  helper_method :current_region
  def current_region
    case SITE_HOST
    when "na.serveme.tf", "localhost"
      "na"
    when "au.serveme.tf"
      "au"
    when "sea.serveme.tf"
      "sea"
    else
      "eu"
    end
  end

  private

  def server_globe_data(server, players)
    {
      id: server.id,
      name: server.name,
      latitude: server.latitude,
      longitude: server.longitude,
      location: server.detailed_location,
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
