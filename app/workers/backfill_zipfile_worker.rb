# typed: strict
# frozen_string_literal: true

class BackfillZipfileWorker
  extend T::Sig
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: 3

  sig { params(reservation_id: Integer).void }
  def perform(reservation_id)
    reservation = Reservation.find_by(id: reservation_id)
    unless reservation
      Rails.logger.warn("BackfillZipfileWorker: Reservation not found with ID #{reservation_id}, skipping.")
      return
    end

    if reservation.zipfile.attached?
      Rails.logger.info("BackfillZipfileWorker: Reservation #{reservation_id} already has zipfile attached, skipping.")
      return
    end

    local_path = reservation.local_zipfile_path
    unless local_path && File.exist?(local_path)
       Rails.logger.warn("BackfillZipfileWorker: Local zip file not found at #{local_path} (for reservation #{reservation_id}), skipping.")
       return
    end

    filename = reservation.zipfile_name

    blob = T.let(nil, T.nilable(ActiveStorage::Blob))
    attachment = nil

    begin
      File.open(local_path, "rb") do |file|
        blob = ActiveStorage::Blob.create_and_upload!(
          io: file,
          filename: filename,
          content_type: "application/zip",
          service_name: :minio
        )
      end
      unless blob
        Rails.logger.error("BackfillZipfileWorker: Blob object is nil after creation attempt for reservation #{reservation_id}, aborting attachment.")
        return
      end
      Rails.logger.info("BackfillZipfileWorker: Blob created for reservation #{reservation_id}, key: #{blob.key}")
    rescue StandardError => e
      backtrace_str = e.backtrace&.join("\n") || "No backtrace available"
      Rails.logger.error("BackfillZipfileWorker: Failed to create blob for reservation #{reservation_id} from #{local_path}: #{e.message}\n#{backtrace_str}")
      return
    end

    begin
      attachment = ActiveStorage::Attachment.new(
        name: "zipfile",
        record_type: "Reservation",
        record_id: reservation_id,
        blob_id: blob.id
      )

      if attachment.save(validate: false)
        Rails.logger.info("BackfillZipfileWorker: Attachment record saved for reservation #{reservation_id} (using IDs).")
      else
        error_details = attachment.errors.full_messages.join(", ")
        Rails.logger.error("BackfillZipfileWorker: Failed to save Attachment record for reservation #{reservation_id} (using IDs). Errors: #{error_details}. Blob key: #{blob.key}.")
      end
    rescue StandardError => e
      backtrace_str = e.backtrace&.join("\n") || "No backtrace available"
      Rails.logger.error("BackfillZipfileWorker: Error during Attachment save for reservation #{reservation_id} (using IDs), blob key: #{blob.key}: #{e.message}\n#{backtrace_str}")
    end

    nil
  end
end
