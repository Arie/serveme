class ReservationsController < ApplicationController

  def time_selection
    @reservation          = Reservation.new(params[:reservation])
    @reservation.user_id  = current_user.id
    @reservation.server   = free_servers.first
    if @reservation.server && !user_already_booked_at_that_time?
      redirect_to new_reservation_path(:server_id => @reservation.server, :starts_at => @reservation.starts_at, :ends_at => @reservation.ends_at)
    else
      flash.now[:alert] = "No servers available in the given timerange" if free_servers.none?
      @reservation.valid?
      render :server_selection
    end
  end

  def server_selection
    @reservation ||= new_reservation
    @servers ||= ServerFinder.available_for_user(current_user)
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
        flash[:notice] = "Reservation created for #{@reservation.server_name}. Give the server a minute to (re)boot/update and <a href='#{@reservation.server_connect_url}'>click here to join</a> or enter in console: #{@reservation.connect_string}".html_safe
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
    if reservation.update_attributes(sanitized_parameters)
      if reservation.now?
        reservation.update_reservation
        flash[:notice] = "Reservation updated for #{reservation}, your changes will be active after a mapchange."
      else
        flash[:notice] = "Reservation updated for #{reservation}"
      end
      redirect_to root_path
    else
      render :edit
    end
  end

  def extend
    if reservation.extend!
      flash[:notice] = "Reservation extended to #{I18n.l(reservation.ends_at, :format => :datepicker)}"
    else
      flash[:alert] = "Could not extend, conflicting reservation"
    end
    redirect_to root_path
  end

  def show
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
    new_reservation_attributes = { :user_id   => current_user.id,
                                   :server    => server,
                                   :starts_at => params[:starts_at] || Time.current,
                                   :ends_at   => params[:ends_at] || 2.hours.from_now }
    if previous_reservation
      previous_reservation_attributes = previous_reservation.attributes.slice('password', 'rcon', 'tv_password', 'disable_source_tv', 'server_config_id', 'whitelist_id')
      new_reservation_attributes.merge!(previous_reservation_attributes)
    end

    Reservation.new(new_reservation_attributes)
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
    ServerFinder.new(current_user, @reservation.starts_at, @reservation.ends_at)
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

  private

  def previous_reservation
    current_user.reservations.last
  end

  def sanitized_parameters
    parameters = params[:reservation].slice(:password, :rcon, :disable_source_tv, :tv_password, :tv_relaypassword, :server_config_id, :whitelist_id)
    if reservation.schedulable?
      parameters.merge!(params[:reservation].slice(:server_id, :starts_at, :ends_at))
    end
    parameters.merge!(:user_id => current_user.id)
  end

end
