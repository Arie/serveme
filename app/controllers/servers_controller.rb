class ServersController < ApplicationController

  skip_before_filter :authenticate_user!
  caches_action :index, :unless => :current_user

  def index
    @servers = Server.active.ordered
  end

end
