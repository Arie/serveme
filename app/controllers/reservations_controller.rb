# frozen_string_literal: true

class ReservationsController < ApplicationController
  before_action :require_admin, only: %i[streaming]
  helper LogLineHelper
  layout 'rcon', only: [:rcon]
  include RconHelper
  include LogLineHelper
  include ReservationsHelper

  def new
    if user_made_two_very_short_reservations_in_last_ten_minutes?
      flash[:alert] = 'You made 2 very short reservations in the last ten minutes, please wait a bit before making another one. If there was a problem with your server, let us know in the comments below'
      redirect_to root_path
    end
    @reservation ||= new_reservation
    @reservation.generate_rcon_password! if @reservation.poor_rcon_password?
  end

  def new_gameye
    @gameye_locations = GameyeServer.locations
    if user_made_two_very_short_reservations_in_last_ten_minutes?
      flash[:alert] = 'You made 2 very short reservations in the last ten minutes, please wait a bit before making another one. If there was a problem with your server, let us know in the comments below'
      redirect_to root_path
    end
    @reservation ||= new_reservation
    @reservation.generate_rcon_password! if @reservation.poor_rcon_password?
  end

  def create_gameye
    @reservation = current_user.reservations.build(reservation_params)
    if @reservation.valid?
      $lock.synchronize('save-reservation-server-gameye') do
        @reservation.save!
      end
      reservation_saved if @reservation.persisted?
    else
      @gameye_locations = GameyeServer.locations
      render :new_gameye
    end
  end

  def create
    @reservation = current_user.reservations.build(reservation_params)
    if @reservation.valid?
      $lock.synchronize("save-reservation-server-#{@reservation.server_id}") do
        @reservation.save!
      end
      reservation_saved if @reservation.persisted?
    else
      render :new
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
    @users_reservations = current_user.reservations.ordered.paginate(page: params[:page], per_page: 20)
  end

  def played_in
    @users_games = Reservation.includes(:user, server: :location).played_in(current_user.uid)
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
      flash[:alert] = 'Could not extend, conflicting reservation'
    end
    redirect_to root_path
  end

  def show
    if reservation
      if reservation.gameye_location.present?
        render :show_gameye
      else
        render :show
      end
    else
      redirect_to new_reservation_path
    end
  end

  def gameye
    if reservation
      render :show_gameye
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
      flash[:alert] = 'Your reservation was started in the last 2 minutes. Please give the server some time to start before ending your reservation'
    else
      end_reservation
    end
    redirect_to reservation_path(@reservation)
  end

  def status
    reservation
    respond_to do |format|
      format.json
    end
  end

  def streaming
    filename = Rails.root.join('log', 'streaming', "#{reservation.logsecret}.log")
    begin
      @streaming_log = File.open(filename)
    rescue Errno::ENOENT
      flash[:error] = "No such streaming logfile #{reservation.logsecret}.log"
      redirect_to reservation_path(reservation)
    end
  end

  def rcon
    @logsecret = reservation.logsecret
    filename = Rails.root.join('log', 'streaming', "#{@logsecret}.log")
    begin
      seek = [File.size(filename), 50_000].min
      @log_lines = File.open(filename) do |f|
        f.seek(-seek, IO::SEEK_END)
        f.readlines.last(500).reverse.select { |l| interesting_line?(l) }.first(100)
      end
    rescue Errno::ENOENT
      @log_lines = []
    end
  end

  def rcon_command
    if reservation&.now?
      rcon_command = clean_rcon(params[:reservation][:rcon_command])
      Rails.logger.info("User #{current_user.name} (#{current_user.uid}) executed rcon command \"#{rcon_command}\" for reservation #{reservation.id}")
      result = reservation.server.rcon_exec(rcon_command).to_s
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.prepend("reservation_#{reservation.logsecret}_log_lines", target: "reservation_#{reservation.logsecret}_log_lines", partial: 'reservations/log_line', locals: { log_line: result }) }
        format.html { redirect_to rcon_reservation_path(reservation) }
      end
    else
      render 'pages/not_found', status: 404
    end
  end

  private

  def reservation
    @reservation ||= find_reservation
  end
  helper_method :reservation

  def reservation_saved
    if @reservation.now?
      @reservation.update_attribute(:start_instantly, true)
      if @reservation.gameye?
        ReservationWorker.new.perform(reservation.id, 'start')
        flash[:notice] = 'Match started on Gameye. The server is now being configured, give it a minute to boot'
        redirect_to gameye_path(@reservation)
      else
        @reservation.start_reservation
        flash[:notice] = "Reservation created for #{@reservation.server_name}. The server is now being configured, give it a minute to start".html_safe
        redirect_to reservation_path(@reservation)
      end
    else
      redirect_to reservation_path(@reservation)
    end
  end

  def user_made_two_very_short_reservations_in_last_ten_minutes?
    count = current_user.reservations
                        .where('starts_at > ?', 10.minutes.ago)
                        .where('ended = ?', true)
                        .count
    !current_user.admin? && count >= 2
  end
end
