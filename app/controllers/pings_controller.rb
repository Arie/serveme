# typed: true

class PingsController < ApplicationController
  def index
    @servers = Server.active.ordered.includes(:location)
    @docker_hosts = DockerHost.active.ordered
  end
end
