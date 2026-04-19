# typed: true
# frozen_string_literal: true

class CloudServerDestroyWorker
  include Sidekiq::Worker

  sidekiq_options retry: 3, queue: "default"

  MAX_PROVISION_WAIT = 15.minutes

  sidekiq_retries_exhausted do |msg, exception|
    cloud_server = CloudServer.find_by(id: msg["args"][0])
    Rails.logger.error "CloudServerDestroyWorker: All retries exhausted for cloud_server #{cloud_server&.id}, provider_id #{cloud_server&.cloud_provider_id}: #{exception}"
  end

  def perform(cloud_server_id)
    cloud_server = CloudServer.find(cloud_server_id)
    return if cloud_server.cloud_status == "destroyed" && cloud_server.cloud_provider_id.blank?

    provider = cloud_server.provider
    provider_id = cloud_server.cloud_provider_id

    if provider_id.present?
      unless provider.destroy_server(provider_id)
        raise "Failed to destroy #{cloud_server.cloud_provider} server #{provider_id} for cloud_server #{cloud_server.id}"
      end
    elsif cloud_server.cloud_status == "provisioning"
      cloud_server.update!(cloud_status: "destroyed", cloud_destroyed_at: Time.current, active: false)
      if cloud_server.cloud_created_at.present? && Time.current - cloud_server.cloud_created_at < MAX_PROVISION_WAIT
        CloudServerDestroyWorker.perform_in(30.seconds, cloud_server_id)
      end
      return
    end

    # Safety net: destroy any orphaned VMs matching this cloud server's label.
    # Catches duplicates created by retries before cloud_provider_id was saved.
    provider.destroy_servers_by_label(provider.cloud_server_name(cloud_server))

    cloud_server.update!(cloud_status: "destroyed", cloud_destroyed_at: Time.current, active: false)
  end
end
