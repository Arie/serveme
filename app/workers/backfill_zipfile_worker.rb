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

    # Skip if already attached to Active Storage
    if T.unsafe(reservation).zipfile.attached?
      Rails.logger.info("BackfillZipfileWorker: Reservation #{reservation_id} already has zipfile attached, skipping.")
      return
    end

    local_path = reservation.local_zipfile_path
    unless local_path && File.exist?(local_path)
      Rails.logger.warn("BackfillZipfileWorker: Local zip file not found at #{local_path} for reservation #{reservation_id}, skipping.")
      return
    end

    begin
      Rails.logger.info("BackfillZipfileWorker: Attaching local zip #{local_path} for reservation #{reservation_id}...")
      File.open(local_path, "rb") do |file|
        T.unsafe(reservation).zipfile.attach(
          io: file,
          filename: reservation.zipfile_name, # Use the correct filename
          content_type: "application/zip"
        )
      end
      Rails.logger.info("BackfillZipfileWorker: Successfully attached zip for reservation #{reservation_id}.")
    rescue StandardError => e
      backtrace_str = e.backtrace&.join("\n") || "No backtrace available"
      Rails.logger.error("BackfillZipfileWorker: Failed to attach zip for reservation #{reservation_id} from #{local_path}: #{e.message}\n#{backtrace_str}")
      # Let Sidekiq handle retry based on sidekiq_options
      raise e
    end
  end
end
