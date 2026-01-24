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
    @initial_query = params[:q].to_s.strip.presence

    file = find_log_file(@file_name)
    file_path = file[:file_name_and_path]
    raise Errno::ENOENT, "Log file not found: #{@file_name}" unless file_path

    service = LogStreamingService.new(file_path, search_query: @initial_query)
    @total_lines = service.total_line_count

    # Pre-render initial lines for non-JS fallback and faster initial display
    # Use larger count to ensure content is visible without JS (for tests and non-JS browsers)
    initial_count = [ @total_lines, 500 ].min
    result = service.view_at_position(position_percent: 0, count: initial_count)
    @initial_lines = result[:lines]
    @initial_start_index = result[:start_index]
    @initial_total_matches = result[:total_matches]
  rescue Errno::ENOENT
    flash[:error] = "Log file not found"
    redirect_to reservation_log_uploads_path(reservation)
  end

  # Virtual scrolling view endpoint for log uploads
  def show_log_view
    setup_log_viewing
    query = params[:q].to_s.strip.presence
    position_percent = params[:percent].to_f.clamp(0, 100)
    count = params[:count].to_i.clamp(10, 500)

    file = find_log_file(@file_name)
    file_path = file[:file_name_and_path]
    raise Errno::ENOENT, "Log file not found: #{@file_name}" unless file_path

    service = LogStreamingService.new(file_path, search_query: query)
    result = service.view_at_position(position_percent: position_percent, count: count)

    # Render the lines as HTML
    html = render_to_string(
      partial: "reservations/log_line",
      formats: [ :html ],
      collection: result[:lines],
      as: :log_line,
      locals: { skip_sanitization: @skip_sanitization }
    )

    render json: {
      html: html,
      total: result[:total],
      total_matches: result[:total_matches],
      start_index: result[:start_index],
      end_index: result[:end_index],
      is_search: result[:is_search],
      line_indices: result[:line_indices]
    }
  rescue Errno::ENOENT
    render json: { error: "Log file not found", html: "", total: 0 }, status: :not_found
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
