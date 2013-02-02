class ReservationsController < ApplicationController

  def new
    @reservation ||= new_reservation
  end

  def time_selection
    @reservation = Reservation.new(params[:reservation])
    @reservation.user_id = current_user.id
    @reservation.server = free_servers.first
    if @reservation.server && !user_already_booked_in_range?(@reservation.starts_at, @reservation.ends_at)
      render :new
    else
      flash.now[:alert] = "No servers available in the given timerange" if free_servers.none?
      @reservation.valid?
      render :server_selection
    end
  end

  def server_selection
    @reservation ||= Reservation.new(:user_id   => current_user.id,
                                     :starts_at => Time.now,
                                     :ends_at   => 2.hours.from_now)
  end

  def index
    @users_reservations = current_user.reservations.ordered.first(100)
  end

  def edit
  end

  def show
  end

  def create
    @reservation = Reservation.new(params[:reservation])
    @reservation.user_id     = current_user.id
    @reservation.date        = Date.today
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

  def extend
    begin
      extend_reservation
    rescue
      flash[:alert] = "Could not extend, conflicting reservation by #{reservation.colliding_reservations.map(&:to_s).join(', ')}"
    ensure
      redirect_to root_path
    end
  end

  def destroy
    if reservation.cancellable?
      cancel_reservation
    else
      end_reservation
    end
    redirect_to root_path
  end

  def reservation
    @reservation ||= find_reservation
  end
  helper_method :reservation

  private

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

  def cancel_reservation
    flash[:notice] = "Reservation for #{@reservation} cancelled"
    reservation.destroy
  end

  def end_reservation
    reservation.end_reservation
    link = "/uploads/#{reservation.zipfile_name}"
    flash[:notice] = "Reservation removed, restarting server. Get your STV demos and logs <a href='#{link}' target=_blank>here</a>".html_safe
  end

  def extend_reservation
    if reservation.extend!
      flash[:notice] = "Reservation extended by 1 hour to #{I18n.l(reservation.ends_at, :format => :datepicker)}"
    end
  end

  def reservable_servers_for_user
    @reservable_servers_for_user ||= Server.reservable_by_user(current_user)
  end
  helper_method :reservable_servers_for_user

  def free_servers
    @free_servers ||= FreeServerFinder.new(reservable_servers_for_user, @reservation.starts_at, @reservation.ends_at).servers
  end

  def user_already_booked_in_range?(starts_at, ends_at)
    FreeServerFinder.new(current_user, starts_at, ends_at).user_already_reserved_a_server_in_range?(current_user, starts_at, ends_at)
  end

end
