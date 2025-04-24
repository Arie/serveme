# typed: false
# frozen_string_literal: true

require "fileutils"

class DownloadZipWorker # Renamed class
  include Sidekiq::Worker
  include ActionView::RecordIdentifier

  sidekiq_options retry: 3

  extend T::Sig

  sig { params(reservation_id: Integer).void }
  def perform(reservation_id)
    reservation = Reservation.find_by(id: reservation_id)
    unless reservation
      Rails.logger.error("DownloadZipWorker: Reservation #{reservation_id} not found.")
      return
    end

    unless T.unsafe(reservation).zipfile.attached?
      Rails.logger.error("DownloadZipWorker: No zipfile attached for Reservation #{reservation_id}.")
      broadcast_error(reservation, "No zipfile found in cloud storage.")
      return
    end

    zip_blob = T.unsafe(reservation).zipfile.blob
    local_path = T.must(reservation.local_zipfile_path)

    if File.exist?(local_path)
      Rails.logger.info("DownloadZipWorker: Local file already exists for Reservation #{reservation_id} at #{local_path}. Broadcasting completion.")
      broadcast_completion(reservation)
      return
    end

    tmp_path = "#{local_path}.tmp"

    begin
      Rails.logger.info("DownloadZipWorker: Starting download for Reservation #{reservation_id} (key: #{zip_blob.key}) to #{tmp_path}")
      FileUtils.mkdir_p(File.dirname(local_path))

      total_size = zip_blob.byte_size
      downloaded_size = 0
      last_reported_progress = -1

      File.open(tmp_path, "wb") do |file|
        zip_blob.download do |chunk|
          file.write(chunk)
          downloaded_size += chunk.bytesize
          progress = ((downloaded_size.to_f / total_size) * 100).round

          if progress > last_reported_progress && (progress % 5 == 0 || progress == 100)
            broadcast_progress(reservation, progress, "Preparing... #{progress}%")
            last_reported_progress = progress
          end
        end
      end

      File.rename(tmp_path, local_path)
      Rails.logger.info("DownloadZipWorker: Successfully downloaded Reservation #{reservation_id} zip to #{local_path}")

      broadcast_completion(reservation)

    rescue ActiveStorage::FileNotFoundError => e
      Rails.logger.error("DownloadZipWorker: Active Storage file not found for Reservation #{reservation_id} (key: #{zip_blob.key}): #{e.message}")
      broadcast_error(reservation, "Cloud file not found.")
      FileUtils.rm_f(tmp_path)
    rescue StandardError => e
      Rails.logger.error("DownloadZipWorker: Error downloading zip for Reservation #{reservation_id}: #{e.message}\n#{e.backtrace.join("\n")}")
      broadcast_error(reservation, "Error during download.")
      FileUtils.rm_f(tmp_path)
    end
  end

  private

  sig { params(reservation: Reservation, progress: Integer, message: String).void }
  def broadcast_progress(reservation, progress, message)
    Turbo::StreamsChannel.broadcast_replace_to(
      reservation,
      target: dom_id(reservation, :zip_download_progress),
      partial: "reservations/zip_download_progress",
      locals: { reservation: reservation, progress: progress, message: message }
    )
  end

  sig { params(reservation: Reservation).void }
  def broadcast_completion(reservation)
    Turbo::StreamsChannel.broadcast_replace_to(
      reservation,
      target: dom_id(reservation, :zip_download_status),
      partial: "reservations/direct_zip_download_link",
      locals: { reservation: reservation }
    )
  end

  sig { params(reservation: Reservation, message: String).void }
  def broadcast_error(reservation, message)
    Turbo::StreamsChannel.broadcast_update_to(
      reservation,
      target: dom_id(reservation, :zip_download_progress),
      content: "<div class='text-danger'>Error: #{message}</div>"
    )
  end
end
