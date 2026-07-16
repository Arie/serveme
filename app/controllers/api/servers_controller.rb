# typed: true
# frozen_string_literal: true

module Api
  class ServersController < Api::ApplicationController
    def index
      @servers = Server.active.not_cloud.includes(:location).order(:name)
    end
  end
end
