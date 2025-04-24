# typed: false
# frozen_string_literal: true

class UploadsController < ApplicationController
  include ActionController::Streaming

  extend T::Sig

  sig { void }
  def show
    reservation_id = params[:id]&.split("-")&.[](1)&.to_i
    unless reservation_id
      Rails.logger.warn("UploadsController: Could not parse reservation ID from params[:id]: #{params[:id]}")
      head :not_found
      return
    end

    reservation = find_permissible_reservation(reservation_id)
    unless reservation
      head :not_found
      return
    end

    if reservation.local_zipfile_available?
      local_path = T.must(reservation.local_zipfile_path)
      Rails.logger.info("Serving local zip for reservation #{reservation.id} from #{local_path}")
      send_file(local_path, filename: reservation.zipfile_name, type: "application/zip", disposition: "attachment")
    elsif T.unsafe(reservation).zipfile.attached?
      begin
        zip_blob = T.unsafe(reservation).zipfile.blob
        Rails.logger.info("Streaming Active Storage zip for reservation #{reservation.id} (key: #{zip_blob.key}, filename: #{zip_blob.filename})")

        response.headers["Content-Type"] = zip_blob.content_type
        response.headers["Content-Disposition"] = ActionDispatch::Http::ContentDisposition.format(disposition: "attachment", filename: zip_blob.filename.to_s)

        zip_blob.download do |chunk|
          response.stream.write(chunk)
        end
      rescue ActiveStorage::FileNotFoundError
        Rails.logger.error("UploadsController: Active Storage file not found for reservation #{reservation.id} (key: #{T.unsafe(reservation).zipfile&.blob&.key})")
        head :not_found
      rescue StandardError => e
        Rails.logger.error("UploadsController: Error downloading/streaming Active Storage zip for reservation #{reservation.id}: #{e.message}\n#{e.backtrace.join("\n")}")
        head :internal_server_error unless response.committed?
      ensure
        response.stream.close if response.stream.respond_to?(:close)
      end
    else
      Rails.logger.warn("UploadsController: No local or Active Storage zip found for reservation #{reservation.id}")
      head :not_found
    end
  end

  private

  sig { params(reservation_id: Integer).returns(T.nilable(Reservation)) }
  def find_permissible_reservation(reservation_id)
    reservation = find_played_or_made_reservation(reservation_id)
    if reservation
      reservation
    elsif current_user&.admin? || current_user&.league_admin? || current_user&.streamer?
      admin_reservation = Reservation.find_by(id: reservation_id)
      if admin_reservation
        Rails.logger.info("ZIP download by admin/special user #{current_user.name} (#{current_user.uid}) for reservation #{admin_reservation.id}")
      else
        Rails.logger.warn("UploadsController: Admin/special user #{current_user&.name} tried to access non-existent reservation ID #{reservation_id}")
      end
      admin_reservation
    else
      Rails.logger.warn("UploadsController: Unauthorized attempt to access reservation ID #{reservation_id} by user #{current_user&.name} (#{current_user&.uid})")
      nil
    end
  end

  sig { params(reservation_id: Integer).returns(T.nilable(Reservation)) }
  def find_played_or_made_reservation(reservation_id)
    return nil unless current_user

    played_in = Reservation.played_in(current_user.uid).find_by(id: reservation_id)
    made_by   = current_user.reservations.find_by(id: reservation_id)

    reservation = played_in || made_by
    if reservation
      Rails.logger.info("User #{current_user.name} (#{current_user.uid}) permitted to download zip for reservation #{reservation.id}")
    end
    reservation
  end
end
