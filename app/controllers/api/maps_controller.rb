# frozen_string_literal: true

module Api
  class MapsController < Api::ApplicationController
    skip_before_action :verify_api_key

    def index
      @maps = MapUpload.available_maps
    end
  end
end
