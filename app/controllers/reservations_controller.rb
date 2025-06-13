# typed: false
# frozen_string_literal: true

class ReservationsController < ApplicationController
  include ActionView::RecordIdentifier # Include for dom_id helper
  before_action :require_admin, only: %i[streaming]
  skip_before_action :redirect_if_country_banned, only: :played_in
  skip_before_action :authenticate_user!, only: %i[motd]
  skip_before_action :store_current_location, only: %i[extend_reservation destroy]
  helper LogLineHelper
  layout "simple", only: %i[rcon motd]
  caches_action :motd, cache_path: -> { "motd_#{params[:id]}" }, unless: -> { current_user }, expires_in: 30.seconds
  include RconHelper
  include LogLineHelper
  include ReservationsHelper

  def new
    if user_made_two_very_short_reservations_in_last_ten_minutes?
      flash[:alert] = "You made 2 very short reservations in the last ten minutes, please wait a bit before making another one. If there was a problem with your server, let us know in the comments below"
      redirect_to root_path
    end
    @reservation ||= new_reservation
    if params[:ip].present?
      available_servers = ServerForUserFinder.new(current_user, @reservation.starts_at, @reservation.ends_at).servers
      matching_servers = available_servers.where(ip: params[:ip])
      server = matching_servers.sample if matching_servers.any?
      @reservation.server_id = server.id if server
    end
    @reservation.generate_rcon_password! if @reservation.poor_rcon_password?
  end

  def create
    @reservation = current_user.reservations.build(reservation_params)
    if @reservation.valid?
      $lock.synchronize("save-reservation-server-#{@reservation.server_id}") do
        @reservation.save!
      end
      reservation_saved if @reservation.persisted?
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def i_am_feeling_lucky
    @reservation = IAmFeelingLucky.new(current_user).build_reservation
    if @reservation.valid?
      $lock.synchronize("save-reservation-server-#{@reservation.server_id}") do
        @reservation.save!
      end
      reservation_saved if @reservation.persisted?
    else
      flash[:alert] = "You're not very lucky, no server is available for the timerange #{@reservation.human_timerange} :("
      redirect_to root_path
    end
  end

  def index
    @users_reservations = current_user.reservations.ordered.with_attached_zipfile.paginate(page: params[:page], per_page: 20)
  end

  def played_in
    @users_games = Reservation.includes(:user, server: :location)
                              .played_in(current_user.uid)
                              .with_attached_zipfile
  end

  def edit
    @reservation = reservation
  end

  def update
    if reservation.past?
      flash[:alert] = "Reservation has expired, can't update it anymore"
      redirect_to root_path
    else
      update_reservation
    end
  end

  def extend_reservation
    if reservation.extend!
      flash[:notice] = "Reservation extended to #{I18n.l(reservation.ends_at, format: :datepicker)}"
    else
      flash[:alert] = "Could not extend, conflicting reservation"
    end
    redirect_to stored_location_for(:user) || root_path
  end

  def show
    if reservation
      render :show
    else
      redirect_to new_reservation_path
    end
  end

  def destroy
    if reservation.cancellable?
      cancel_reservation
      redirect_to root_path
      return
    elsif reservation.just_started?
      flash[:alert] = "Your reservation was started in the last 2 minutes. Please give the server some time to start before ending your reservation"
    else
      end_reservation
    end
    redirect_to reservation_path(@reservation)
  end

  def status
    reservation
    respond_to(&:json)
  end

  def streaming
    filename = Rails.root.join("log", "streaming", "#{reservation.logsecret}.log")
    begin
      @streaming_log = File.open(filename)
    rescue Errno::ENOENT
      flash[:error] = "No such streaming logfile #{reservation.logsecret}.log"
      redirect_to reservation_path(reservation)
    end
  end

  def rcon
    @logsecret = reservation.logsecret
    filename = Rails.root.join("log", "streaming", "#{@logsecret}.log")
    begin
      seek = [ File.size(filename), 50_000 ].min
      @log_lines = File.open(filename) do |f|
        f.seek(-seek, IO::SEEK_END)
        f.readlines.last(1000).reverse.select do |line|
          interesting_line?(ActiveSupport::Multibyte::Chars.new(line).tidy_bytes.to_s)
        end.first(200)
      end
    rescue Errno::ENOENT
      @log_lines = []
    end
  end

  def rcon_command
    shared_rcon_command(rcon_reservation_path(reservation))
  end

  def rcon_autocomplete
    @query = params[:query]
    @suggestions = RconAutocomplete.new(reservation).autocomplete(@query)
    @reservation_id = params[:reservation_id].to_i
    render layout: false
  end

  def motd
    @reservation = Reservation.find(params[:id])

    return head(:unauthorized) unless @reservation.password == params[:password]

    rcon if current_user && (current_user == @reservation.user || current_user.admin?)
  end

  def motd_rcon_command
    shared_rcon_command(motd_reservation_path(reservation))
  end

  def stac_log
    @reservation = Reservation.find(params[:id])
    @stac_logs = @reservation.stac_logs

    if @stac_logs.any?
      contents = @stac_logs.map do |log|
        content = ActiveSupport::Multibyte::Chars.new(log.contents).tidy_bytes.to_s
        content.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
      end.join("\n")

      send_data contents.force_encoding("UTF-8"),
                filename: "stac_logs_#{@reservation.id}.log",
                type: "text/plain; charset=UTF-8",
                disposition: "inline",
                status: :ok
    else
      render plain: "No STAC logs found", status: :not_found
    end
  end

  def prepare_zip
    @reservation = find_reservation
    head :not_found unless @reservation

    local_file_path = @reservation.local_zipfile_path
    if local_file_path && File.exist?(local_file_path)
      render_direct_zip_link
    elsif T.unsafe(@reservation).zipfile.attached?
      enqueue_zip_download_and_render_progress
    else
      render_zip_unavailable_error
    end
  end

  private

  def shared_rcon_command(return_path)
    if reservation&.now?
      rcon_command = clean_rcon(params[:query] || params[:reservation][:rcon_command])
      Rails.logger.info("User #{current_user.name} (#{current_user.uid}) executed rcon command \"#{rcon_command}\" for reservation #{reservation.id}")
      result = handle_rcon_command(rcon_command)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.prepend("reservation_#{reservation.logsecret}_log_lines", target: "reservation_#{reservation.logsecret}_log_lines", partial: "reservations/log_line", locals: { log_line: result }) }
        format.html { redirect_to return_path }
      end
    else
      render "pages/not_found", status: 404
    end
  end

  def handle_rcon_command(rcon_command)
    case rcon_command
    when "extend", "!extend"
      if reservation.extend!
        "Reservation extended to #{I18n.l(reservation.ends_at, format: :datepicker)}"
      else
        "Could not extend, conflicting reservation"
      end
    when "end", "!end"
      end_reservation
      "Ending reservation"
    else
      reservation.server.rcon_exec(rcon_command).to_s
    end
  end

  def reservation
    @reservation ||= find_reservation
  end
  helper_method :reservation

  def reservation_saved
    if @reservation.now?
      @reservation.update_attribute(:start_instantly, true)
      @reservation.start_reservation
      flash[:notice] = "Reservation created for #{@reservation.server_name}. The server is now being configured, give it a minute to start".html_safe
    end
    redirect_to reservation_path(@reservation)
  end

  def user_made_two_very_short_reservations_in_last_ten_minutes?
    count = current_user.reservations
                        .where("starts_at > ?", 10.minutes.ago)
                        .where("ended = ?", true)
                        .count
    !current_user.admin? && count >= 2
  end

  def render_direct_zip_link
    Rails.logger.info("Prepare zip for Reservation #{@reservation.id}: File exists locally. Rendering direct link.")
    render turbo_stream: turbo_stream.replace(
      dom_id(@reservation, :zip_download_status),
      partial: "reservations/direct_zip_download_link",
      locals: { reservation: @reservation }
    )
  end

  def enqueue_zip_download_and_render_progress
    Rails.logger.info("Prepare zip for Reservation #{@reservation.id}: File not local, zip attached. Enqueuing worker and rendering progress.")
    DownloadZipWorker.perform_async(@reservation.id)

    render turbo_stream: [
      turbo_stream.replace(
        dom_id(@reservation, :zip_prepare_button_form),
        partial: "reservations/zip_download_progress",
        locals: { reservation: @reservation, progress: 0, message: "Preparing... 0%" }
      ),
      turbo_stream.append_all(
        "body",
        helpers.turbo_stream_from(@reservation)
      )
    ]
  end

  def render_zip_unavailable_error
    Rails.logger.warn("Prepare zip for Reservation #{@reservation.id}: File not local and no zip attached.")
    # Consider a Turbo Stream update here too, to inform the user
    head :unprocessable_entity
  end

  def reservation_params
    permitted_params = %i[id password tv_password tv_relaypassword server_config_id whitelist_id custom_whitelist_id first_map auto_end enable_plugins enable_demos_tf disable_democheck]
    permitted_params += %i[rcon server_id starts_at ends_at] if reservation.nil? || reservation&.schedulable?
    params.require(:reservation).permit(permitted_params)
  end
end
