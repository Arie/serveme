# typed: strict
# frozen_string_literal: true

class ZipUploadWorker
  extend T::Sig
  include Sidekiq::Worker
  sidekiq_options retry: 20

  sig { params(reservation_id: Integer).void }
  def perform(reservation_id)
    reservation = Reservation.find(reservation_id)

    if ActiveStorage::Attachment.exists?(record_type: "Reservation", record_id: reservation_id, name: "zipfile")
      Rails.logger.info("ZipUploadWorker: Reservation #{reservation_id} already has zipfile attached, skipping.")
      return
    end

    blob = T.let(nil, T.untyped)
    begin
      File.open(reservation.local_zipfile_path.to_s, "rb") do |file|
        blob = ActiveStorage::Blob.create_and_upload!(
          io: file,
          filename: File.basename(reservation.local_zipfile_path.to_s),
          content_type: "application/zip",
          service_name: :seaweedfs
        )
      end
      Rails.logger.info("ZipUploadWorker: Blob created for reservation #{reservation_id}, key: #{blob&.key}")
    rescue StandardError => e
      backtrace_str = e.backtrace&.join("\n") || "No backtrace available"
      Rails.logger.error("ZipUploadWorker: Error during Blob creation for reservation #{reservation_id}, path: #{reservation.local_zipfile_path}: #{e.message}\n#{backtrace_str}")
      Reservation.find_by(id: reservation_id)&.status_update("Failed to upload zip file (blob creation)")
      raise e
    end

    unless blob
      Rails.logger.error("ZipUploadWorker: Blob object is nil after creation attempt for reservation #{reservation_id}, aborting attachment.")
      Reservation.find_by(id: reservation_id)&.status_update("Failed to upload zip file (blob nil)")
      return
    end

    begin
      attachment = ActiveStorage::Attachment.new(
        name: "zipfile",
        record_type: "Reservation",
        record_id: reservation_id,
        blob_id: blob&.id
      )

      if attachment.save(validate: false)
        Rails.logger.info("ZipUploadWorker: Attachment record saved for reservation #{reservation_id} (using IDs).")
        Reservation.find_by(id: reservation_id)&.status_update("Finished uploading zip file to storage")
      else
        error_details = attachment.errors.full_messages.join(", ")
        Rails.logger.error("ZipUploadWorker: Failed to save Attachment record for reservation #{reservation_id} (using IDs). Errors: #{error_details}. Blob key: #{blob&.key}.")
        Reservation.find_by(id: reservation_id)&.status_update("Failed to attach zip file (attachment save)")
      end
    rescue StandardError => e
      backtrace_str = e.backtrace&.join("\n") || "No backtrace available"
      Rails.logger.error("ZipUploadWorker: Error during Attachment save for reservation #{reservation_id} (using IDs), blob key: #{blob&.key}: #{e.message}\n#{backtrace_str}")
      Reservation.find_by(id: reservation_id)&.status_update("Failed to attach zip file (attachment error)")
    end
  end
end
