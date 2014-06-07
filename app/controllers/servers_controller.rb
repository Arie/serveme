class ServersController < ApplicationController

  skip_before_filter :authenticate_user!

  def index
    SteamCondenser::Servers::Sockets::BaseSocket.timeout = 500
    @servers = Server.active.order(:name)
  end

end
