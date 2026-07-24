# typed: true
# frozen_string_literal: true

class CloudServerCleanupWorker
  include Sidekiq::Worker

  sidekiq_options retry: false, queue: "default"

  MAX_AGE = 6.hours

  def perform
    cutoff = MAX_AGE.ago
    # cloud_created_at is stamped once the provider starts creating; rows that
    # fail before that (e.g. DNS outage) only have created_at to age them by.
    CloudServer.where(cloud_status: %w[provisioning ssh_ready ready])
               .where("cloud_created_at < :cutoff OR (cloud_created_at IS NULL AND created_at < :cutoff)", cutoff: cutoff)
               .find_each do |server|
      reservation = reservation_for(server)
      next if reservation && !reservation.ended? && reservation.ends_at&.>(15.minutes.ago)

      Rails.logger.info "CloudServerCleanupWorker: Destroying stranded cloud server #{server.id} (created #{server.cloud_created_at})"
      end_stranded_reservation(server)
      CloudServerDestroyWorker.perform_async(server.id)
    end
  end

  private

  # A server stranded before provisioning finished may not have
  # cloud_reservation_id set yet, while a live reservation already references it
  # via server_id, so fall back to the forward-pointer.
  def reservation_for(server)
    Reservation.find_by(id: server.cloud_reservation_id) ||
      Reservation.where(server_id: server.id).order(created_at: :desc).first
  end

  def end_stranded_reservation(server)
    reservation = reservation_for(server)
    return unless reservation
    return if reservation.ended?

    Rails.logger.info "CloudServerCleanupWorker: Ending stranded reservation #{reservation.id} for cloud server #{server.id}"
    reservation.update_columns(ended: true, ends_at: Time.current, duration: Time.current.to_i - reservation.starts_at.to_i)
  end
end
