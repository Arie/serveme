class ReservationsController < ApplicationController

  include ReservationsHelper

  def new
    if user_made_two_very_short_reservations_in_last_ten_minutes?
      flash[:alert] = "You made 2 very short reservations in the last ten minutes, please wait a bit before making another one. If there was a problem with your server, let us know in the comments below"
      redirect_to root_path
    end
    @reservation ||= new_reservation
  end

  def create
    @reservation = current_user.reservations.build(reservation_params)
    if @reservation.save
      reservation_saved
    else
      render :new
    end
  end

  def i_am_feeling_lucky
    @reservation = IAmFeelingLucky.new(current_user).build_reservation
    if @reservation.save
      reservation_saved
    else
      flash[:alert] = "You're not very lucky, no server is available for the timerange #{@reservation.human_timerange} :("
      redirect_to root_path
    end
  end

  def index
    @users_reservations = current_user.reservations.ordered.paginate(:page => params[:page], :per_page => 20)
  end

  def played_in
    @users_games = Reservation.played_in(current_user.uid)
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
     flash[:notice] = "Reservation extended to #{I18n.l(reservation.ends_at, :format => :datepicker)}"
   else
     flash[:alert] = "Could not extend, conflicting reservation"
   end
   redirect_to root_path
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
    elsif reservation.just_started?
      flash[:alert] = "Your reservation was started in the last 2 minutes. Please give the server some time to start before ending your reservation"
    else
      end_reservation
    end
    redirect_to root_path
  end

  def idle_reset
    flash[:notice] = "Reservation idle timer reset"
    reservation.update_attribute(:inactive_minute_counter, 0)
    redirect_to reservation_path(reservation)
  end

  private

  def reservation
    @reservation ||= find_reservation
  end
  helper_method :reservation

  def reservation_saved
    if @reservation.now?
      @reservation.update_attribute(:start_instantly, true)
      @reservation.start_reservation
      flash[:notice] = "Reservation created for #{@reservation.server_name}. The server is now being configured, give it a minute to (re)boot/update and <a href='#{@reservation.server_connect_url}'>click here to join</a> or enter in console: #{@reservation.connect_string}".html_safe
      redirect_to reservation_path(@reservation)
    else
      flash[:notice] = "Reservation created for #{@reservation}"
      redirect_to root_path
    end
  end

  def user_made_two_very_short_reservations_in_last_ten_minutes?
    count = current_user.reservations.
      where('starts_at > ?', 10.minutes.ago).
      where('ended = ?', true).
      count
    count >= 2
  end

end
