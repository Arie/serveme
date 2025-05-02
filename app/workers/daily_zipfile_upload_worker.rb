# typed: strict
# frozen_string_literal: true

class DailyZipfileUploadWorker
  extend T::Sig
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: 1

  sig { void }
  def perform
    Rails.logger.info("DailyZipfileUploadWorker: Starting job.")
    start_time = Time.current
    two_days_ago = start_time - 2.days
    processed_count = 0
    uploaded_count = 0

    reservations_to_check = Reservation
                            .where(ended: true)
                            .where("reservations.ends_at >= ?", two_days_ago)
                            .where.missing(:zipfile_attachment)

    reservations_to_check.find_each do |reservation|
      processed_count += 1
      zip_path = reservation.local_zipfile_path

      if zip_path && File.exist?(zip_path)
        ZipUploadWorker.new.perform(reservation.id)
        uploaded_count += 1
      end
    end

    duration = Time.current - start_time
    Rails.logger.info("DailyZipfileUploadWorker: Finished job in #{duration.round(2)}s. Processed #{processed_count} reservations, uploaded #{uploaded_count} zips.")
  end
end
