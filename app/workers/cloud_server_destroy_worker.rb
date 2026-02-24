# typed: true
# frozen_string_literal: true

class CloudServerDestroyWorker
  include Sidekiq::Worker

  sidekiq_options retry: 3, queue: "default"

  def perform(cloud_server_id)
    cloud_server = CloudServer.find(cloud_server_id)
    return if cloud_server.cloud_status == "destroyed"

    provider_id = cloud_server.cloud_provider_id
    if provider_id.present?
      provider = cloud_server.provider
      provider.destroy_server(provider_id)
    end

    cloud_server.update!(cloud_status: "destroyed", cloud_destroyed_at: Time.current, active: false)
  end
end
