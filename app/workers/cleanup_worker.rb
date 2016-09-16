# frozen_string_literal: true
class CleanupWorker
  include Sidekiq::Worker

  def perform
    remove_old_reservation_logs_and_zips
    remove_old_statistics
  end

  def remove_old_reservation_logs_and_zips
    old_reservations.find_each do |reservation|
      logs_dir = Rails.root.join("server_logs", "#{reservation.id}")
      streaming_log = Rails.root.join("log", "streaming", "#{reservation.logsecret}.log")
      zip = Rails.root.join("public", "uploads", "#{reservation.zipfile_name}")
      if Dir.exists?(logs_dir)
        Rails.logger.info "Remove files for old reservation #{reservation.id} #{reservation}"
        FileUtils.rm_rf([logs_dir, zip])
        FileUtils.rm_f([streaming_log])
      end
    end
  end

  def remove_old_statistics
    old_player_statistics.delete_all
    old_server_statistics.delete_all
    old_reservation_statuses.delete_all
  end

  def old_reservations
    Reservation.where('ends_at < ? AND ends_at > ?', 31.days.ago, 35.days.ago)
  end

  def old_reservation_statuses
    ReservationStatus.where('created_at < ?', 31.days.ago)
  end

  def old_player_statistics
    PlayerStatistic.where('created_at < ?', 7.days.ago)
  end

  def old_server_statistics
    ServerStatistic.where('created_at < ?', 35.days.ago)
  end

end

