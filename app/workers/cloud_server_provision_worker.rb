# typed: true
# frozen_string_literal: true

class CloudServerProvisionWorker
  include Sidekiq::Worker

  sidekiq_options retry: 3, queue: "priority"

  sidekiq_retries_exhausted do |msg, _exception|
    cloud_server = CloudServer.find_by(id: msg["args"][0])
    cloud_server&.update!(cloud_status: "destroyed", cloud_destroyed_at: Time.current, active: false)
  end

  def perform(cloud_server_id)
    cloud_server = CloudServer.find(cloud_server_id)

    if cloud_server.cloud_provider_id.present?
      CloudServerPollWorker.perform_in(5.seconds, cloud_server_id)
      return
    end

    reservation = Reservation.find_by(id: cloud_server.cloud_reservation_id)
    provider = cloud_server.provider

    reservation&.status_update("Creating #{cloud_server.cloud_provider} VM in #{cloud_server.cloud_location}, this takes #{provider.estimated_provision_time}")

    begin
      provider_id = provider.create_server(cloud_server)
    rescue => e
      reservation&.status_update("Failed to create VM: #{e.message}")
      raise
    end

    cloud_server.update!(cloud_provider_id: provider_id)

    if provider.respond_to?(:server_progress)
      reservation&.status_update("Creating VM (0%)")
    else
      reservation&.status_update("Creating VM")
    end

    CloudServerPollWorker.perform_in(5.seconds, cloud_server_id)
  end
end
