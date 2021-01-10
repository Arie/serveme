# frozen_string_literal: true

module Api
  class ServersController < Api::ApplicationController
    def index
      @servers = Server.active.order(:name)
    end
  end
end
