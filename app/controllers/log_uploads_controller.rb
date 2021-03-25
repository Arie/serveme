# frozen_string_literal: true

class LogUploadsController < ApplicationController
  def new
    @log_upload = link_log_upload_to_reservation
    log_file = find_log_file(params[:file_name].to_s)
    @log_upload.file_name = log_file.fetch(:file_name)
  end

  def create
    @log_upload = LogUpload.new(upload_params)
    link_log_upload_to_reservation
    log_file = find_log_file(upload_params[:file_name].to_s)
    @log_upload.file_name = log_file.fetch(:file_name)
    if @log_upload.save
      @log_upload.upload
      flash[:notice] = 'Logfile uploaded to logs.tf'
      redirect_to(reservation_log_uploads_path(reservation))
    else
      render :new
    end
  end

  def index
    @logs         = logs
    @log_uploads  = log_uploads
  end

  def show_log
    file = find_log_file(params[:file_name].to_s)
    file_content = File.read(file[:file_name_and_path])
    @log_file = ActiveSupport::Multibyte::Chars.new(file_content).tidy_bytes
  end

  private

  def link_log_upload_to_reservation
    @log_upload ||= LogUpload.new
    @log_upload.reservation_id = reservation.id
    @log_upload
  end

  def reservation
    @reservation ||= if params[:reservation_id].to_i.positive?
                       if current_admin
                         Reservation.find(params[:reservation_id].to_i)
                       else
                         current_user.reservations.find(params[:reservation_id].to_i)
                       end
                     end
  end
  helper_method :reservation

  def logs
    @logs ||= LogUpload.find_log_files(reservation.id)
  end

  def find_log_file(file_name)
    logs.find { |log| log[:file_name] == file_name } || { file_name: nil }
  end

  def log_uploads
    @log_uploads ||= reservation.log_uploads.order('created_at DESC')
  end

  def upload_params
    params.require(:log_upload).permit(:file_name, :title, :map_name)
  end
end
