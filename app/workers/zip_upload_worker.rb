# typed: strict
# frozen_string_literal: true

class ZipUploadWorker
  extend T::Sig
  include Sidekiq::Worker
  sidekiq_options retry: 3

  sig { params(reservation_id: Integer, zipfile_path: String).void }
  def perform(reservation_id, zipfile_path)
    reservation = Reservation.find_by(id: reservation_id)
    unless reservation
      Rails.logger.error("ZipUploadWorker: Reservation not found with ID #{reservation_id}")
      return
    end

    unless File.exist?(zipfile_path)
      Rails.logger.error("ZipUploadWorker: Zip file not found at path #{zipfile_path} for reservation #{reservation_id}")
      reservation.status_update("Failed to upload zip file: File not found at #{zipfile_path}")
      return
    end

    reservation.status_update("Uploading zip file to storage")
    begin
      File.open(zipfile_path) do |file|
        T.unsafe(reservation).zipfile.attach(
          io: file,
          filename: File.basename(zipfile_path),
          content_type: "application/zip"
        )
      end
      reservation.status_update("Finished uploading zip file to storage")
    rescue StandardError => e
      backtrace_str = e.backtrace&.join("\n") || "No backtrace available"
      Rails.logger.error("ZipUploadWorker: Failed to upload zip for reservation #{reservation.id}: #{e.message}\n#{backtrace_str}")
      reservation.status_update("Failed to upload zip file")
      raise e
    end
  end
end
