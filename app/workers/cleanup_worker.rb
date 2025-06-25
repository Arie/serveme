# typed: true
# frozen_string_literal: true

class CleanupWorker
  include Sidekiq::Worker

  def perform
    remove_old_reservation_logs_and_zips
    remove_old_statistics
    grant_api_keys_to_week_old_users
    PopulateResolvedIpsService.call
  end

  def remove_old_reservation_logs_and_zips
    `find /var/www/serveme/shared/server_logs/ -type d -ctime +#{Reservation.cleanup_age_in_days} -exec rm -rf {} \\;`
    `find /var/www/serveme/shared/log/streaming/*.log -type f -mtime +#{Reservation.cleanup_age_in_days} -exec rm -f {} \\;`
    `find /var/www/serveme/shared/public/uploads/*.zip -type f -mtime +#{Reservation.cleanup_age_in_days} -exec rm -f {} \\;`
  end

  def remove_old_statistics
    old_player_statistics.delete_all
    old_server_statistics.delete_all
    old_reservation_statuses.delete_all
  end

  def grant_api_keys_to_week_old_users
    User.where("created_at < ?", 7.days.ago).where(api_key: nil).find_in_batches do |group|
      group.each do |u|
        u.generate_api_key!
      end
    end
  end

  def old_reservations
    Reservation.where("ends_at < ? AND ends_at > ?", 28.days.ago, 35.days.ago)
  end

  def old_reservation_statuses
    ReservationStatus.where("created_at < ?", 31.days.ago)
  end

  def old_player_statistics
    PlayerStatistic.where("created_at < ?", 7.days.ago)
  end

  def old_server_statistics
    ServerStatistic.where("created_at < ?", 35.days.ago)
  end
end
