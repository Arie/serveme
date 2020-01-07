# frozen_string_literal: true

class Api::ServersController < Api::ApplicationController
  def index
    @servers = Server.active.order(:name)
  end
end
