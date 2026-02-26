# typed: true
# frozen_string_literal: true

class CloudServerRconPollWorker
  include Sidekiq::Worker

  sidekiq_options retry: 0, queue: "default"

  MAX_POLL_TIME = 2.minutes

  def perform(reservation_id)
    reservation = Reservation.find_by(id: reservation_id)
    return unless reservation
    return if reservation.provisioned?
    return if reservation.ended?

    server = reservation.server
    return unless server.is_a?(CloudServer)
    return if server.cloud_status == "destroyed"

    begin
      result = server.rcon_exec("status")
      if result.present?
        mark_ready!(reservation, server)
        return
      end
    rescue SteamCondenser::Error, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT
      # Server not ready yet, will retry
    end

    if too_long_since_tf2_ready?(server)
      Rails.logger.warn "CloudServerRconPollWorker: Server #{server.id} rcon not responding after #{MAX_POLL_TIME}, giving up"
      return
    end

    CloudServerRconPollWorker.perform_in(3.seconds, reservation_id)
  end

  private

  def mark_ready!(reservation, server)
    reservation.update_columns(provisioned: true, ready_at: Time.current)
    reservation.status_update("TF2 server ready")
    server.broadcast_reservation_status
  end

  def too_long_since_tf2_ready?(server)
    return false unless server.cloud_status == "ready"

    # Use cloud_created_at as a conservative upper bound
    server.cloud_created_at.present? && server.cloud_created_at < (MAX_POLL_TIME + 10.minutes).ago
  end
end
