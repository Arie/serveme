class ReservationsController < ApplicationController

  include ReservationsHelper

  def time_selection
    @reservation          = current_user.reservations.build(reservation_params)
    @reservation.server   = free_servers.first
    if @reservation.server && !user_already_booked_at_that_time?
      redirect_to new_reservation_path(:server_id => @reservation.server, :starts_at => @reservation.starts_at, :ends_at => @reservation.ends_at)
    else
      if free_servers.none?
        flash.now[:alert] = "No servers available in the given timerange"
        @donator_nag = true unless current_user.donator?
      end
      @reservation.valid?
      render :server_selection
    end
  end

  def server_selection
    @reservation ||= new_reservation
  end

  def new
    @reservation ||= new_reservation
  end

  def create
    @reservation = current_user.reservations.build(reservation_params)
    if @reservation.save
      if @reservation.now?
        @reservation.update_attribute(:start_instantly, true)
        @reservation.start_reservation
        flash[:notice] = "Reservation created for #{@reservation.server_name}. The server is now being configured, give it a minute to (re)boot/update and <a href='#{@reservation.server_connect_url}'>click here to join</a> or enter in console: #{@reservation.connect_string}".html_safe
        redirect_to reservation_path(@reservation)
      else
        flash[:notice] = "Reservation created for #{@reservation}"
        redirect_to root_path
      end
    else
      render :new
    end
  end

  def index
    @users_reservations = current_user.reservations.ordered.paginate(:page => params[:page], :per_page => 20)
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

  def server
    @server ||= find_server
  end
  helper_method :server



end
