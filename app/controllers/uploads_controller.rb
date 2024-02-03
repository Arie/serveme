# frozen_string_literal: true

class UploadsController < ApplicationController
  def show
    reservation_id = params[:id]&.split('-')&.[](1)&.to_i
    reservation = Reservation.played_in(current_user.uid).where(id: reservation_id).first
    if reservation
      zip_file_path = Rails.root.join('public', reservation.zipfile_name)
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
