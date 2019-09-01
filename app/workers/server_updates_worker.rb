# frozen_string_literal: true
class ServerUpdatesWorker
  include Sidekiq::Worker

  def perform
    latest_version = Server.get_latest_version
    Rails.cache.write("latest_server_version", latest_version) if latest_version
  end
end
