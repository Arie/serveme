# frozen_string_literal: true

class ServersController < ApplicationController
  def index
    @servers = Server.active.includes([current_reservations: { user: :groups }], :location, :recent_server_statistics).order(:name)
    if current_admin || current_league_admin || current_streamer
      render :admins
    else
      render :index
    end
  end
end
