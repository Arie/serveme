# frozen_string_literal: true

module Api
  class MapsController < Api::ApplicationController
    def index
      @maps = MapUpload.available_maps
      @cloud_maps = MapUpload.available_cloud_maps
    end
  end
end
