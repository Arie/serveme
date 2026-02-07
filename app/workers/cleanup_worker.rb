# typed: true
# frozen_string_literal: true

require "safe_file_deletion"

class CleanupWorker
  include Sidekiq::Worker

  def perform
    remove_old_reservation_logs_and_zips
    remove_old_statistics
    grant_api_keys_to_week_old_users
    remove_orphaned_temp_directories
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
    User.where(created_at: ...7.days.ago).where(api_key: nil).find_in_batches do |group|
      group.each do |u|
        u.generate_api_key!
      end
    end
  end

  def old_reservations
    Reservation.where(ends_at: 35.days.ago...28.days.ago)
  end

  def old_reservation_statuses
    ReservationStatus.where(created_at: ...31.days.ago)
  end

  def old_player_statistics
    PlayerStatistic.where(created_at: ...7.days.ago)
  end

  def old_server_statistics
    ServerStatistic.where(created_at: ...35.days.ago)
  end

  def remove_orphaned_temp_directories
    cleanup_local_orphaned_temp_directories
    cleanup_ssh_orphaned_temp_directories
  end

  def cleanup_local_orphaned_temp_directories
    cutoff_time = 24.hours.ago
    orphaned_count = 0

    Dir.glob("/tmp/reservation-*").each do |dir|
      next unless File.directory?(dir)
      next unless File.stat(dir).mtime < cutoff_time

      begin
        # Use safe deletion with validation
        if SafeFileDeletion.safe_remove_directory(dir)
          orphaned_count += 1
          Rails.logger.info("CleanupWorker: Removed orphaned local temp directory: #{dir}")
        end
      rescue SafeFileDeletion::InvalidPathError => e
        Rails.logger.error("CleanupWorker: Invalid path from glob #{dir}: #{e.message}")
      rescue StandardError => e
        Rails.logger.error("CleanupWorker: Error removing orphaned local temp directory #{dir}: #{e.message}")
      end
    end

    Rails.logger.info("CleanupWorker: Cleaned up #{orphaned_count} orphaned local temp directories") if orphaned_count.positive?
  end

  def cleanup_ssh_orphaned_temp_directories
    cutoff_time = 24.hours.ago
    cutoff_timestamp = cutoff_time.to_i

    SshServer.active.find_each do |server|
      cleanup_ssh_server_temp_directories(server, cutoff_timestamp)
    end
  end

  def cleanup_ssh_server_temp_directories(server, cutoff_timestamp)
    tf_dir = server.tf_dir
    find_command = "find #{tf_dir.shellescape} -maxdepth 1 -type d -name 'temp_reservation_*' -mtime +1 2>/dev/null || true"

    begin
      result = server.execute(find_command)
      orphaned_dirs = result.split("\n").map(&:strip).reject(&:empty?)

      if orphaned_dirs.any?
        orphaned_dirs.each do |dir|
          begin
            # Validate path before sending rm -rf to remote server
            SafeFileDeletion.validate_temp_directory!(dir)
            server.execute("rm -rf #{dir.shellescape}")
            Rails.logger.info("CleanupWorker: Removed orphaned remote temp directory on #{server.name}: #{dir}")
          rescue SafeFileDeletion::InvalidPathError => e
            Rails.logger.error("CleanupWorker: Invalid remote temp directory path #{dir} on #{server.name}: #{e.message}")
          rescue StandardError => e
            Rails.logger.error("CleanupWorker: Error removing orphaned remote temp directory #{dir} on #{server.name}: #{e.message}")
          end
        end
        Rails.logger.info("CleanupWorker: Cleaned up #{orphaned_dirs.size} orphaned remote temp directories on #{server.name}")
      end
    rescue StandardError => e
      Rails.logger.error("CleanupWorker: Error listing orphaned temp directories on #{server.name}: #{e.message}")
    end
  end
end
