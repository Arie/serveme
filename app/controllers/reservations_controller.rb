class ReservationsController < ApplicationController

  def time_selection
    @reservation          = Reservation.new(params[:reservation])
    @reservation.user_id  = current_user.id
    @reservation.server   = free_servers.first
    if @reservation.server && !user_already_booked_at_that_time?
      render :new
    else
      flash.now[:alert] = "No servers available in the given timerange" if free_servers.none?
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
    @reservation = Reservation.new(params[:reservation])
    @reservation.user_id     = current_user.id
    if @reservation.save
      if @reservation.now?
        @reservation.start_reservation
        flash[:notice] = "Reservation created for #{@reservation.server_name}. Give the server a minute to (re)boot and <a href='#{@reservation.server_connect_url}'>click here to join</a> or enter in console: #{@reservation.connect_string}".html_safe
      else
        flash[:notice] = "Reservation created for #{@reservation}"
      end
      redirect_to root_path
    else
      render :new
    end
  end

  def index
    @users_reservations = current_user.reservations.ordered.first(100)
  end

  def edit
  end

  def extend
    begin
      extend_reservation
    rescue ActiveRecord::RecordInvalid
      flash[:alert] = "Could not extend, conflicting reservation by #{reservation.colliding_reservations.map(&:to_s).join(', ')}"
    ensure
      redirect_to root_path
    end
  end

  def show
  end

  def destroy
    if reservation.cancellable?
      cancel_reservation
    else
      end_reservation
    end
    redirect_to root_path
  end

  private

  def reservation
    @reservation ||= find_reservation
  end
  helper_method :reservation

  def find_reservation
    if params[:id]
      current_user.reservations.find(params[:id].to_i)
    end
  end

  def new_reservation
    Reservation.new(:user_id   => current_user.id,
                    :server    => server,
                    :starts_at => Time.now,
                    :ends_at   => 2.hours.from_now)
  end

  def server
    @server ||= find_server
  end
  helper_method :server

  def find_server
    if params[:server_id]
      Server.find(params[:server_id].to_i)
    end
  end

  def free_servers
    free_server_finder.servers
  end

  def user_already_booked_at_that_time?
    free_server_finder.user_already_reserved_a_server_in_range?
  end

  def free_server_finder
    FreeServerFinder.new(current_user, @reservation.starts_at, @reservation.ends_at)
  end

  def extend_reservation
    if reservation.extend!
      flash[:notice] = "Reservation extended by 1 hour to #{I18n.l(reservation.ends_at, :format => :datepicker)}"
    end
  end

  def cancel_reservation
    flash[:notice] = "Reservation for #{@reservation} cancelled"
    reservation.destroy
  end

  def end_reservation
    reservation.end_reservation
    link = "/uploads/#{reservation.zipfile_name}"
    flash[:notice] = "Reservation removed, restarting server. Get your STV demos and logs <a href='#{link}' target=_blank>here</a>".html_safe
  end

end
