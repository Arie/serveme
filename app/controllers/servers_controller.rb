# frozen_string_literal: true
class ServersController < ApplicationController

  before_action :require_donator

  def index
    SteamCondenser::Servers::Sockets::BaseSocket.timeout = 500
    @servers = Server.active.order(:name)
  end

end
