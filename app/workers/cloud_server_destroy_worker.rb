# typed: true
# frozen_string_literal: true

class CloudServerDestroyWorker
  include Sidekiq::Worker

  sidekiq_options retry: 3, queue: "default"

  MAX_PROVISION_WAIT = 15.minutes

  def perform(cloud_server_id)
    cloud_server = CloudServer.find(cloud_server_id)
    return if cloud_server.cloud_status == "destroyed" && cloud_server.cloud_provider_id.blank?

    provider_id = cloud_server.cloud_provider_id
    if provider_id.present?
      provider = cloud_server.provider
      provider.destroy_server(provider_id)
      cloud_server.update!(cloud_status: "destroyed", cloud_destroyed_at: Time.current, active: false)
    elsif cloud_server.cloud_status == "provisioning"
      cloud_server.update!(cloud_status: "destroyed", cloud_destroyed_at: Time.current, active: false)
      if cloud_server.cloud_created_at.present? && Time.current - cloud_server.cloud_created_at < MAX_PROVISION_WAIT
        CloudServerDestroyWorker.perform_in(30.seconds, cloud_server_id)
      end
    else
      cloud_server.update!(cloud_status: "destroyed", cloud_destroyed_at: Time.current, active: false)
    end
  end
end
