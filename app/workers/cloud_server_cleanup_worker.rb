# typed: true
# frozen_string_literal: true

class CloudServerCleanupWorker
  include Sidekiq::Worker

  sidekiq_options retry: false, queue: "default"

  MAX_AGE = 6.hours

  def perform
    CloudServer.where(cloud_status: %w[provisioning ssh_ready ready])
               .where(cloud_created_at: ...MAX_AGE.ago)
               .find_each do |server|
      Rails.logger.info "CloudServerCleanupWorker: Destroying stranded cloud server #{server.id} (created #{server.cloud_created_at})"
      end_stranded_reservation(server)
      CloudServerDestroyWorker.perform_async(server.id)
    end
  end

  private

  def end_stranded_reservation(server)
    reservation = Reservation.find_by(id: server.cloud_reservation_id)
    return unless reservation
    return if reservation.ended?

    Rails.logger.info "CloudServerCleanupWorker: Ending stranded reservation #{reservation.id} for cloud server #{server.id}"
    reservation.update_columns(ended: true, ends_at: Time.current, duration: Time.current.to_i - reservation.starts_at.to_i)
  end
end
