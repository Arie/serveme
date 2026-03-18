# typed: true
# frozen_string_literal: true

module Api
  class CloudServersController < ActionController::Base
    skip_forgery_protection
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
    before_action :verify_callback_token

    # POST /api/cloud_servers/:id/ready
    def ready
      cloud_server = CloudServer.find(params[:id])
      status = params[:status]

      case status
      when "ssh_ready"
        handle_ssh_ready(cloud_server)
      when "tf2_ready"
        handle_tf2_ready(cloud_server)
      end

      head :ok
    end

    private

    def handle_ssh_ready(cloud_server)
      updates = { cloud_status: "ssh_ready", cloud_ssh_ready_at: Time.current }
      # The callback comes from the VM itself — use its IP if we don't have one yet
      if cloud_server.ip.blank? || cloud_server.ip == "0.0.0.0"
        updates[:ip] = request.remote_ip
      end
      # Only transition from provisioning — ignore duplicate callbacks (e.g. after Kamatera reboot)
      updated = CloudServer.where(id: cloud_server.id, cloud_status: "provisioning")
        .update_all(updates)
      return unless updated > 0

      reservation = Reservation.find(T.must(cloud_server.cloud_reservation_id))
      return if reservation.ended?

      reservation.status_update("Server ready, sending config files")
      ReservationWorker.perform_async(reservation.id, "start")
    end

    def handle_tf2_ready(cloud_server)
      # Ignore duplicate callbacks (e.g. after Kamatera reboot)
      return if cloud_server.cloud_status == "ready"

      if cloud_server.ip.blank? || cloud_server.ip == "0.0.0.0"
        cloud_server.update!(ip: request.remote_ip)
      end
      cloud_server.mark_ready!
      reservation = Reservation.find(T.must(cloud_server.cloud_reservation_id))
      return if reservation.ended?
      return if reservation.provisioned?

      reservation.status_update("TF2 port open, checking server readiness")
      cloud_server.broadcast_reservation_status
      CloudServerRconPollWorker.perform_async(reservation.id)
    end

    def verify_callback_token
      token = request.headers["X-Callback-Token"]
      return head :unauthorized unless token.present?

      cloud_server = CloudServer.find_by(id: params[:id])
      return head :not_found unless cloud_server
      return head :unauthorized unless cloud_server.cloud_callback_token.present?

      head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(token, cloud_server.cloud_callback_token)
    end

    def record_not_found
      head :not_found
    end
  end
end
