# typed: true
# frozen_string_literal: true

class LogUploadsController < ApplicationController
  helper LogLineHelper
  include LogLineHelper
  layout "simple", only: %i[show_log]

  def new
    @log_upload = link_log_upload_to_reservation
    log_file = find_log_file(params[:file_name].to_s)
    @log_upload.file_name = log_file.fetch(:file_name)
  end

  def create
    respond_to do |format|
      format.html do
        @log_upload = LogUpload.new(upload_params)
        link_log_upload_to_reservation
        log_file = find_log_file(upload_params[:file_name].to_s)
        @log_upload.file_name = log_file.fetch(:file_name)

        if @log_upload.save
          @log_upload.upload
          flash[:notice] = "Logfile uploaded to logs.tf"
          redirect_to(reservation_log_uploads_path(reservation))
        else
          render :new, status: :unprocessable_entity
        end
      end
    end
  end

  def index
    @logs         = logs
    @log_uploads  = log_uploads
  end

  def show_log
    setup_log_viewing
    result = log_streaming_service.stream_forward
    assign_log_result(result)
  rescue Errno::ENOENT
    flash[:error] = "Log file not found"
    redirect_to reservation_log_uploads_path(reservation)
  end

  def show_log_load_more
    setup_log_viewing
    chunk_size = params[:chunk_size].to_i.nonzero? || LogStreamingService::DEFAULT_CHUNK_SIZE

    result = log_streaming_service(chunk_size: chunk_size).stream_forward
    render partial: "log_uploads/show_log_chunk", locals: {
      log_lines: result[:lines],
      skip_sanitization: @skip_sanitization,
      has_more: result[:has_more],
      next_offset: result[:next_offset],
      total_lines: result[:total_lines],
      loaded_lines: result[:loaded_lines],
      search_query: @search_query,
      matched_lines: result[:matched_lines],
      reservation: reservation,
      file_name: @file_name
    }
  rescue Errno::ENOENT
    head :not_found
  end

  private

  def setup_log_viewing
    @file_name = params[:file_name].to_s
    @skip_sanitization = current_user&.admin?
    @search_query = params[:q].presence
    @offset = params[:offset].to_i
  end

  def log_streaming_service(chunk_size: nil)
    file = find_log_file(@file_name)
    file_path = file[:file_name_and_path]
    raise Errno::ENOENT, "Log file not found: #{@file_name}" unless file_path

    LogStreamingService.new(
      file_path,
      search_query: @search_query,
      offset: @offset,
      chunk_size: chunk_size || LogStreamingService::DEFAULT_CHUNK_SIZE
    )
  end

  def assign_log_result(result)
    @log_lines = result[:lines]
    @total_lines = result[:total_lines]
    @matched_lines = result[:matched_lines]
    @has_more = result[:has_more]
    @next_offset = result[:next_offset]
    @loaded_lines = result[:loaded_lines]
  end


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
    @log_uploads ||= reservation.log_uploads.order(created_at: :desc)
  end

  def upload_params
    params.require(:log_upload).permit(:file_name, :title, :map_name)
  end
end
