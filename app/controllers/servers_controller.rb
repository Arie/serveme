# frozen_string_literal: true
class ServersController < ApplicationController

  before_filter :require_donator
  caches_action :index, :unless => :current_user, expires_in: 1.minute

  def index
    SteamCondenser::Servers::Sockets::BaseSocket.timeout = 500
    @servers = Server.active.includes([current_reservations: { :user => :groups } ], :location).order(:name)
  end

end
