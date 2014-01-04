module ReservationsHelper

  def update_reservation
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

  def find_reservation
    if params[:id].to_i > 0
      current_user.reservations.find(params[:id].to_i)
    end
  end

  def new_reservation
    new_reservation_attributes = { :user_id   => current_user.id,
                                   :server    => server,
                                   :starts_at => params[:starts_at] || Time.current,
                                   :ends_at   => params[:ends_at] || 2.hours.from_now }
    if previous_reservation
      previous_reservation_attributes = previous_reservation.attributes.slice('password', 'rcon', 'tv_password', 'disable_source_tv', 'server_config_id', 'whitelist_id', 'custom_whitelist_id', 'first_map')
      new_reservation_attributes.merge!(previous_reservation_attributes)
    end

    Reservation.new(new_reservation_attributes)
  end

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
    reservation.update_attribute(:end_instantly, true)
    link = "/uploads/#{reservation.zipfile_name}"
    flash[:notice] = "Reservation removed, restarting server. Your STV demos and logs will be available <a href='#{link}' target=_blank>here</a> shortly".html_safe
  end

  def previous_reservation
    current_user.reservations.last
  end

end
