# typed: false
# frozen_string_literal: true

class PlayersController < ApplicationController
  def index
    @servers_with_players = CurrentPlayersService.cached_servers_with_current_players
    @distance_unit = distance_unit

    if current_admin || current_league_admin || current_streamer
      render :admins
    else
      render :index
    end
  end
end
