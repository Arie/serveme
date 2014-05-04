class ReservationCleanupWorker
  include Sidekiq::Worker
  include Sidetiq::Schedulable

  recurrence { daily.hour_of_day(6) }

  def perform
    remove_old_reservation_logs_and_zips
  end

  def remove_old_reservation_logs_and_zips
    old_reservations.each do |reservation|
      logs_dir = Rails.root.join("server_logs", "#{reservation.id}")
      zip = Rails.root.join("public", "uploads", "#{reservation.zipfile_name}")
      if Dir.exists?(logs_dir)
        Rails.logger.info "Remove files for old reservation #{reservation.id} #{reservation}"
        FileUtils.rm_rf([logs_dir, zip])
      end
    end
  end

  def old_reservations
    Reservation.where('ends_at < ? AND ends_at > ?', 32.days.ago, 40.days.ago)
  end


end

