# typed: true
# frozen_string_literal: true

class ServerVersionWorker
  include Sidekiq::Worker
  sidekiq_options retry: false

  def perform
    latest_version = Server.fetch_latest_version
    Rails.cache.write("latest_server_version", latest_version) if latest_version
    ServerUpdateWorker.perform_async(latest_version) if Server.latest_version
  rescue Faraday::ConnectionFailed
    Rails.logger.info "Failed to fetch latest TF2 version from api.steampowered.com"
  end
end
