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
      updated = CloudServer.where(id: cloud_server.id)
        .where.not(cloud_status: "destroyed")
        .update_all(cloud_status: "ssh_ready", cloud_ssh_ready_at: Time.current)
      return unless updated > 0

      reservation = Reservation.find(T.must(cloud_server.cloud_reservation_id))
      return if reservation.ended?

      reservation.status_update("Server ready, sending config files")
      ReservationWorker.perform_async(reservation.id, "start")
    end

    def handle_tf2_ready(cloud_server)
      cloud_server.mark_ready!
      reservation = Reservation.find(T.must(cloud_server.cloud_reservation_id))
      return if reservation.ended?

      reservation.provisioned = true
      reservation.ready_at = Time.current
      reservation.save(validate: false)
      reservation.status_update("TF2 server ready")
      cloud_server.broadcast_reservation_status
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
