module ReservationsHelper

  def find_servers_for_user
    @reservation = current_user.reservations.build(reservation_params)
    @servers = free_servers
    render :find_servers
  end

  def find_servers_for_reservation
    @reservation = reservation
    @servers = free_servers
    render :find_servers
  end

  def update_reservation
    if reservation.update_attributes(reservation_params)
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

  def find_reservation
    if params[:id].to_i > 0
      if current_user.admin?
        Reservation.find(params[:id].to_i)
      else
        current_user.reservations.find(params[:id].to_i)
      end
    end
  end

  def new_reservation
    new_reservation_attributes = { :starts_at => params[:starts_at] || Time.current,
                                   :ends_at   => params[:ends_at] || 2.hours.from_now }
    if previous_reservation
      previous_reservation_attributes = previous_reservation.attributes.slice('password', 'rcon', 'tv_password', 'server_config_id', 'whitelist_id', 'custom_whitelist_id', 'first_map', 'auto_end')
      new_reservation_attributes.merge!(previous_reservation_attributes)
    end

    current_user.reservations.build(new_reservation_attributes)
  end

  def free_servers
    @free_servers ||= free_server_finder.servers
  end

  def free_server_finder
    if @reservation.persisted?
      if params[:reservation]
        @reservation.starts_at = reservation_params[:starts_at]
        @reservation.ends_at = reservation_params[:ends_at]
      end
      ServerForReservationFinder.new(@reservation)
    else
      ServerForUserFinder.new(current_user, @reservation.starts_at, @reservation.ends_at)
    end
  end

  def cancel_reservation
    flash[:notice] = "Reservation for #{@reservation} cancelled"
    reservation.destroy
  end

  def end_reservation
    reservation.update_attribute(:end_instantly, true)
    reservation.end_reservation
    link = "/uploads/#{reservation.zipfile_name}"
    flash[:notice] = "Reservation removed, restarting server. Your STV demos and logs will be available <a href='#{link}' target=_blank>here</a> shortly".html_safe
  end

  def previous_reservation
    current_user.reservations.last
  end

  private

  def reservation_params
    permitted_params = [:id, :password, :tv_password, :tv_relaypassword, :server_config_id, :whitelist_id, :custom_whitelist_id, :first_map, :auto_end]
    if reservation.nil? || (reservation && reservation.schedulable?)
      permitted_params += [:rcon, :server_id, :starts_at, :ends_at]
    end
    params.require(:reservation).permit(permitted_params)
  end

end
