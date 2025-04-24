# typed: false
# frozen_string_literal: true

class UploadsController < ApplicationController
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
    else
      Rails.logger.warn("UploadsController: Local zip not found for reservation #{reservation.id}. File might be in cloud or not available.")
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
