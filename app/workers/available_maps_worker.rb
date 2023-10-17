# frozen_string_literal: true

class AvailableMapsWorker
  include Sidekiq::Worker

  def perform
    MapUpload.refresh_available_maps
  end
end
