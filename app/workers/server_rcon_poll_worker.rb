# typed: true
# frozen_string_literal: true

class ServerRconPollWorker
  include Sidekiq::Worker

  sidekiq_options retry: 0, queue: "default"

  MAX_POLL_TIME = 2.minutes

  def perform(reservation_id, started_at_s)
    reservation = Reservation.find_by(id: reservation_id)
    return unless reservation
    return if reservation.ready_at.present?
    return if reservation.ended?

    server = reservation.server
    return unless server
    return if server.is_a?(CloudServer)

    begin
      result = server.rcon_exec("status")
      if result.present?
        mark_ready!(reservation)
        return
      end
    rescue SteamCondenser::Error, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT
      # Server not ready yet, will retry
    end

    started_at = Time.zone.parse(started_at_s)
    if started_at < MAX_POLL_TIME.ago
      Rails.logger.warn "ServerRconPollWorker: Reservation #{reservation_id} rcon not responding after #{MAX_POLL_TIME}, giving up"
      return
    end

    ServerRconPollWorker.perform_in(3.seconds, reservation_id, started_at_s)
  end

  private

  def mark_ready!(reservation)
    reservation.update_columns(ready_at: Time.current) if reservation.ready_at.nil?
    reservation.status_update("Server ready")
  end
end
