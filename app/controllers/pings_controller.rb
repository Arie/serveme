# typed: true

class PingsController < ApplicationController
  def index
    @servers = Server.active.ordered.includes(:location)
  end
end
