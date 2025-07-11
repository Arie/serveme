# typed: true
# frozen_string_literal: true

require "fileutils"

class DownloadZipWorker # Renamed class
  include Sidekiq::Worker
  include ActionView::RecordIdentifier

  sidekiq_options retry: 3

  extend T::Sig

  sig { params(reservation_id: Integer).void }
  def perform(reservation_id)
    @reservation = Reservation.find_by(id: reservation_id)
    unless @reservation
      Rails.logger.error("DownloadZipWorker: Reservation #{reservation_id} not found.")
      return
    end

    unless T.unsafe(@reservation).zipfile.attached?
      Rails.logger.error("DownloadZipWorker: No zipfile attached for Reservation #{reservation_id}.")
      broadcast_error("No zipfile found in cloud storage.")
      return
    end

    @zip_blob = T.unsafe(@reservation).zipfile.blob
    @local_path = T.must(@reservation.local_zipfile_path)
    @tmp_path = "#{@local_path}.tmp"

    begin
      download_blob_with_progress
      handle_download_success
    rescue ActiveStorage::FileNotFoundError => e
      handle_download_error(e, "Cloud file not found.")
    rescue StandardError => e
      handle_download_error(e, "Error during download.")
    end
  end

  private

  def download_blob_with_progress
    Rails.logger.info("DownloadZipWorker: Starting download for Reservation #{@reservation.id} (key: #{@zip_blob.key}) to #{@tmp_path}")
    FileUtils.mkdir_p(File.dirname(@local_path))

    total_size = @zip_blob.byte_size
    downloaded_size = 0
    last_reported_progress = -1
    last_broadcast_time = Time.current

    File.open(@tmp_path, "wb") do |file|
      @zip_blob.download do |chunk|
        file.write(chunk)
        downloaded_size += chunk.bytesize
        progress = ((downloaded_size.to_f / total_size) * 100).round
        current_time = Time.current

        # Throttle progress updates
        if progress > last_reported_progress && (progress == 100 || current_time - last_broadcast_time >= 0.2)
          broadcast_progress(progress, "Preparing... #{progress}%")
          last_reported_progress = progress
          last_broadcast_time = current_time
        end
      end
    end
  end

  def handle_download_success
    File.rename(@tmp_path, @local_path)
    Rails.logger.info("DownloadZipWorker: Successfully downloaded Reservation #{@reservation.id} zip to #{@local_path}")
    broadcast_completion
  end

  def handle_download_error(error, user_message)
    Rails.logger.error("DownloadZipWorker: Error downloading zip for Reservation #{@reservation.id}: #{error.message}\n#{error.backtrace.join("\n")}")
    broadcast_error(user_message)
    FileUtils.rm_f(@tmp_path)
  end

  # Broadcast helpers now operate on @reservation implicitly
  sig { params(progress: Integer, message: String).void }
  def broadcast_progress(progress, message)
    progress_target_id = dom_id(@reservation, :zip_download_progress)
    Turbo::StreamsChannel.broadcast_action_to(
      @reservation,
      action: :update,
      target: progress_target_id,
      partial: "reservations/zip_download_progress_bar",
      locals: { reservation: @reservation, progress: progress, message: message }
    )
  end

  sig { void }
  def broadcast_completion
    Turbo::StreamsChannel.broadcast_replace_to(
      @reservation,
      target: dom_id(@reservation, :zip_download_status),
      partial: "reservations/direct_zip_download_link",
      locals: { reservation: @reservation }
    )
  end

  sig { params(message: String).void }
  def broadcast_error(message)
    Turbo::StreamsChannel.broadcast_update_to(
      @reservation,
      target: dom_id(@reservation, :zip_download_progress),
      content: "<div class='text-danger'>Error: #{message}</div>"
    )
  end
end
