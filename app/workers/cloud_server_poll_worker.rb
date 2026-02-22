# typed: true
# frozen_string_literal: true

class CloudServerPollWorker
  include Sidekiq::Worker

  sidekiq_options retry: 0, queue: "default"

  MAX_POLL_TIME = 10.minutes

  def perform(cloud_server_id)
    cloud_server = CloudServer.find(cloud_server_id)
    return if cloud_server.cloud_status == "ready"
    return if cloud_server.cloud_status == "destroyed"

    if stale?(cloud_server)
      Rails.logger.warn "CloudServerPollWorker: Server #{cloud_server_id} timed out, destroying"
      reservation = Reservation.find_by(id: cloud_server.cloud_reservation_id)
      reservation&.status_update("Cloud server failed to start, destroying VM")
      CloudServerDestroyWorker.perform_async(cloud_server_id)
      return
    end

    provider = cloud_server.provider
    provider_id = cloud_server.cloud_provider_id
    return unless provider_id.present?

    begin
      status = provider.server_status(provider_id)
      reservation = Reservation.find_by(id: cloud_server.cloud_reservation_id)

      if status == "running"
        ip = provider.server_ip(provider_id)
        if ip.present? && cloud_server.ip != ip
          cloud_server.update!(ip: ip)
          if reservation
            existing = reservation.reservation_statuses.find_by("status LIKE 'Creating VM%'")
            existing&.update!(status: "Creating VM (100%)")
            reservation.status_update("VM running at #{ip}, waiting for SSH")
            reservation.broadcast_connect_info
          end
        end
      elsif status == "provisioning" && provider.respond_to?(:server_progress)
        progress = provider.server_progress(provider_id)
        if progress && reservation
          existing = reservation.reservation_statuses.find_by("status LIKE 'Creating VM%'")
          new_status = "Creating VM (#{progress}%)"
          if existing
            existing.update!(status: new_status)
          else
            reservation.status_update(new_status)
          end
        end
      end
    rescue => e
      Rails.logger.warn "CloudServerPollWorker: Transient error for server #{cloud_server_id}: #{e.message}"
      CloudServerPollWorker.perform_in(10.seconds, cloud_server_id)
      return
    end

    # Re-poll unless the phone-home callback has already marked it ready
    cloud_server.reload
    unless cloud_server.cloud_status.in?(%w[ssh_ready ready])
      CloudServerPollWorker.perform_in(5.seconds, cloud_server_id)
    end
  end

  private

  def stale?(cloud_server)
    cloud_server.cloud_created_at.present? && cloud_server.cloud_created_at < MAX_POLL_TIME.ago
  end
end
