# typed: true
# frozen_string_literal: true

module Api
  class MapsController < Api::ApplicationController
    skip_before_action :verify_api_key
    skip_before_action :set_default_response_format

    respond_to :json, :text

    def index
      @maps = MapUpload.available_maps

      respond_to do |format|
        format.json
        format.text do
          maps_text = Rails.cache.fetch("api_maps_text", expires_in: 10.minutes) do
            MapUpload.available_maps.sort.join("\n")
          end
          render plain: maps_text
        end
      end
    end
  end
end
