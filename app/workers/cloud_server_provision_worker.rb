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
    return if cloud_server.cloud_status == "destroyed"

    if cloud_server.cloud_provider_id.present?
      CloudServerPollWorker.perform_in(5.seconds, cloud_server_id)
      return
    end

    reservation = Reservation.find_by(id: cloud_server.cloud_reservation_id)
    unless reservation
      cloud_server.update!(cloud_status: "destroyed", cloud_destroyed_at: Time.current, active: false)
      return
    end

    # Reset cloud_created_at so the poll worker's staleness timer starts from
    # actual provisioning, not from when the record was first created (which
    # could be hours earlier for future-scheduled reservations).
    cloud_server.update!(cloud_created_at: Time.current)

    provider = cloud_server.provider

    reservation.status_update("Creating #{cloud_server.cloud_provider} VM in #{cloud_server.cloud_location}, this takes #{provider.estimated_provision_time}")

    begin
      provider_id = provider.create_server(cloud_server)
    rescue => e
      reservation.status_update("Failed to create VM: #{e.message}")
      raise
    end

    # Save provider_id immediately so retries won't create duplicate VMs
    cloud_server.update!(cloud_provider_id: provider_id)

    unless provider.respond_to?(:pending_command?) && provider.pending_command?(provider_id)
      ip = provider.server_ip(provider_id)
      cloud_server.update!(ip: ip) if ip.present?
    end

    cloud_server.reload
    if cloud_server.cloud_status == "destroyed"
      provider.destroy_server(provider_id)
      return
    end

    cloud_server.reload
    unless cloud_server.cloud_status.in?(%w[ssh_ready ready])
      reservation.status_update("Creating VM")
      CloudServerPollWorker.perform_in(5.seconds, cloud_server_id)
    end
  end
end
