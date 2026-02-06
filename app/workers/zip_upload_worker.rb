# typed: strict
# frozen_string_literal: true

class ZipUploadWorker
  extend T::Sig
  include Sidekiq::Worker
  sidekiq_options retry: 20

  sig { params(reservation_id: Integer).void }
  def perform(reservation_id)
    reservation = Reservation.find(reservation_id)
    return if already_attached?(reservation_id)

    blob = create_or_find_blob(reservation)

    if blob
      attach_blob_to_reservation(reservation_id, blob)
    else
      Rails.logger.error("ZipUploadWorker: Blob object is nil after creation attempt for reservation #{reservation_id}, aborting attachment.")
      Reservation.find_by(id: reservation_id)&.status_update("Failed to upload zip file (blob nil)")
    end
  end

  private

  sig { params(reservation_id: Integer).returns(T::Boolean) }
  def already_attached?(reservation_id)
    if ActiveStorage::Attachment.exists?(record_type: "Reservation", record_id: reservation_id, name: "zipfile")
      Rails.logger.info("ZipUploadWorker: Reservation #{reservation_id} already has zipfile attached, skipping.")
      true
    else
      false
    end
  end

  sig { params(reservation: Reservation).returns(T.nilable(ActiveStorage::Blob)) }
  def create_or_find_blob(reservation)
    File.open(reservation.local_zipfile_path.to_s, "rb") do |file|
      blob = ActiveStorage::Blob.create_and_upload!(
        io: file,
        filename: File.basename(reservation.local_zipfile_path.to_s),
        content_type: "application/zip",
        service_name: :seaweedfs
      )
      Rails.logger.info("ZipUploadWorker: Blob created for reservation #{reservation.id}, key: #{blob&.key}") if blob
      blob
    end
  rescue Net::ReadTimeout, Net::WriteTimeout, Aws::S3::MultipartUploadError => e
    handle_timeout_error(reservation, e)
  rescue StandardError => e
    handle_standard_error(reservation, e)
  end

  sig { params(reservation: Reservation, error: Exception).returns(T.nilable(ActiveStorage::Blob)) }
  def handle_timeout_error(reservation, error)
    Rails.logger.warn("ZipUploadWorker: Timeout during blob creation for reservation #{reservation.id}: #{error.class} - #{error.message}")

    recent_blob = find_recent_blob(reservation)
    validate_and_use_blob(reservation, recent_blob, error, "timeout")
  end

  sig { params(reservation: Reservation, error: Exception).returns(T.nilable(ActiveStorage::Blob)) }
  def handle_standard_error(reservation, error)
    recent_blob = find_recent_blob(reservation)

    if recent_blob && blob_complete?(recent_blob, T.must(reservation.local_zipfile_path))
      Rails.logger.warn("ZipUploadWorker: Error during blob creation for reservation #{reservation.id}, but found complete existing blob #{recent_blob.key}, will attempt attachment: #{error.class} - #{error.message}")
      recent_blob
    elsif recent_blob
      purge_incomplete_blob(reservation, recent_blob, error, "error")
    else
      backtrace_str = error.backtrace&.join("\n") || "No backtrace available"
      Rails.logger.error("ZipUploadWorker: Error during Blob creation for reservation #{reservation.id}, path: #{reservation.local_zipfile_path}: #{error.message}\n#{backtrace_str}")
      Reservation.find_by(id: reservation.id)&.status_update("Failed to upload zip file (blob creation)")
      raise error
    end
  end

  sig { params(reservation: Reservation).returns(T.nilable(ActiveStorage::Blob)) }
  def find_recent_blob(reservation)
    filename = File.basename(reservation.local_zipfile_path.to_s)
    ActiveStorage::Blob.where(filename: filename, service_name: :seaweedfs)
                       .where("created_at > ?", 1.hour.ago)
                       .order(created_at: :desc)
                       .first
  end

  sig { params(reservation: Reservation, blob: T.nilable(ActiveStorage::Blob), error: Exception, context: String).returns(T.nilable(ActiveStorage::Blob)) }
  def validate_and_use_blob(reservation, blob, error, context)
    unless blob
      backtrace_str = error.backtrace&.join("\n") || "No backtrace available"
      Rails.logger.error("ZipUploadWorker: #{error.message} for reservation #{reservation.id}, path: #{reservation.local_zipfile_path}\n#{backtrace_str}")
      Reservation.find_by(id: reservation.id)&.status_update("Failed to upload zip file (#{context}, no blob found)")
      raise error
    end

    if blob_complete?(blob, T.must(reservation.local_zipfile_path))
      Rails.logger.info("ZipUploadWorker: Found complete existing blob #{blob.key} for reservation #{reservation.id} despite #{context}, will attempt attachment")
      blob
    else
      purge_incomplete_blob(reservation, blob, error, context)
    end
  end

  sig { params(reservation: Reservation, blob: ActiveStorage::Blob, error: Exception, context: String).returns(T.noreturn) }
  def purge_incomplete_blob(reservation, blob, error, context)
    expected_size = File.size(reservation.local_zipfile_path.to_s)
    Rails.logger.warn("ZipUploadWorker: Found incomplete blob #{blob.key} for reservation #{reservation.id} (expected: #{expected_size}, actual: #{blob.byte_size}), deleting and retrying")
    blob.purge
    backtrace_str = error.backtrace&.join("\n") || "No backtrace available"
    Rails.logger.error("ZipUploadWorker: #{context.capitalize} occurred with incomplete blob for reservation #{reservation.id}, path: #{reservation.local_zipfile_path}: #{error.message}\n#{backtrace_str}")
    Reservation.find_by(id: reservation.id)&.status_update("Failed to upload zip file (#{context}, incomplete blob)")
    raise error
  end

  sig { params(reservation_id: Integer, blob: ActiveStorage::Blob).void }
  def attach_blob_to_reservation(reservation_id, blob)
    attachment = ActiveStorage::Attachment.new(
      name: "zipfile",
      record_type: "Reservation",
      record_id: reservation_id,
      blob_id: blob.id
    )

    if attachment.save(validate: false)
      Rails.logger.info("ZipUploadWorker: Attachment record saved for reservation #{reservation_id}.")
      Reservation.find_by(id: reservation_id)&.status_update("Finished uploading zip file to storage")
    else
      error_details = attachment.errors.full_messages.join(", ")
      Rails.logger.error("ZipUploadWorker: Failed to save Attachment record for reservation #{reservation_id}. Errors: #{error_details}. Blob key: #{blob.key}.")
      Reservation.find_by(id: reservation_id)&.status_update("Failed to attach zip file (attachment save)")
    end
  rescue StandardError => e
    backtrace_str = e.backtrace&.join("\n") || "No backtrace available"
    Rails.logger.error("ZipUploadWorker: Error during Attachment save for reservation #{reservation_id}, blob key: #{blob.key}: #{e.message}\n#{backtrace_str}")
    Reservation.find_by(id: reservation_id)&.status_update("Failed to attach zip file (attachment error)")
  end

  sig { params(blob: ActiveStorage::Blob, local_file_path: Pathname).returns(T::Boolean) }
  def blob_complete?(blob, local_file_path)
    local_file_size = File.size(local_file_path.to_s)
    blob.byte_size == local_file_size
  end
end
