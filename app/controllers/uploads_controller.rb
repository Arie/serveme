# typed: false
# frozen_string_literal: true

class UploadsController < ApplicationController
  def show
    reservation_id = params[:id]&.split("-")&.[](1)&.to_i
    respond_to do |format|
      format.zip do
        reservation = find_reservation(reservation_id)
        if reservation
          zip_file_path = Rails.root.join("public", "uploads", reservation.zipfile_name)
          if File.exist?(zip_file_path)
            send_file(zip_file_path)
          else
            head :not_found
          end
        else
          head :not_found
        end
      end
    end
  end

  private

  def find_reservation(reservation_id)
    played_or_made_reservation = played_or_made_reservation(reservation_id)
    if played_or_made_reservation.nil? && (current_user.admin? || current_user.league_admin? || current_user.streamer?)
      reservation = Reservation.find(reservation_id)
      Rails.logger.info("ZIP download by #{current_user.name} (#{current_user.uid}) for reservation #{reservation.id} made by #{reservation&.user&.uid}") if reservation
      reservation
    else
      played_or_made_reservation
    end
  end

  def played_or_made_reservation(reservation_id)
    played_in_reservation = Reservation.played_in(current_user.uid).where(id: reservation_id).first
    own_reservation = current_user.reservations.where(id: reservation_id).first

    played_in_reservation || own_reservation
  end
end
