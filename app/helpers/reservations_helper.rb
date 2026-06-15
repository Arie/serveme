# typed: true
# frozen_string_literal: true

module ReservationsHelper
  extend T::Sig

  # NOTE: this "helper" is also `include`d directly into ReservationsController and
  # Api::ReservationsController, so it relies on controller context (params, render,
  # redirect_to, respond_to, flash, current_user, current_admin, reservation, route
  # helpers). Because Rails ALSO mounts it into every controller's ActionView helper
  # proxy, there is no single ancestor common to all include sites for a
  # `requires_ancestor`. Several of those controller methods (current_admin, etc.) are
  # PRIVATE, so they must be called with implicit self; `T.bind(self, T.untyped)`
  # rebinds self to untyped in-method so bare calls type-check without changing dispatch.

  sig { returns(T.untyped) }
  def find_servers_for_user
    T.bind(self, T.untyped)
    @reservation = new_reservation
    @servers = free_servers
    @docker_hosts = free_docker_hosts
    render :find_servers
  end

  sig { returns(T.untyped) }
  def find_servers_for_reservation
    T.bind(self, T.untyped)
    @reservation = reservation
    @servers = free_servers
    @docker_hosts = free_docker_hosts
    render :find_servers
  end

  sig { returns(T.untyped) }
  def update_reservation
    T.bind(self, T.untyped)
    respond_to do |format|
      format.html do
        if reservation.update(reservation_params)
          if reservation.now?
            reservation.update_reservation
            flash[:notice] = "Reservation updated for #{reservation}, your changes will be active after a mapchange."
          else
            flash[:notice] = "Reservation updated for #{reservation}"
          end
          redirect_to root_path
        else
          @servers = Server.active.not_cloud.ordered.includes(:location)
          render :edit, status: :unprocessable_entity
        end
      end
    end
  rescue ActiveRecord::RecordNotUnique
    reservation.errors.add(:server_id, "already booked in the selected timeframe")
    @servers = Server.active.not_cloud.ordered.includes(:location)
    render :edit, status: :unprocessable_entity
  end

  sig { returns(T.nilable(Reservation)) }
  def find_reservation
    T.bind(self, T.untyped)
    return unless params[:id].to_i.positive?

    if current_admin || current_league_admin || current_streamer
      Reservation.find(params[:id].to_i)
    else
      current_user.reservations.find(params[:id].to_i)
    end
  end

  sig { returns(T.nilable(Reservation)) }
  def find_reservation_for_viewing
    T.bind(self, T.untyped)
    return unless params[:id].to_i.positive?

    if current_admin || current_league_admin || current_streamer
      Reservation.find(params[:id].to_i)
    else
      current_user.reservations.find(params[:id].to_i)
    end
  end

  sig { returns(Reservation) }
  def new_reservation
    T.bind(self, T.untyped)
    new_reservation_attributes = {
      starts_at: starts_at,
      ends_at: ends_at,
      enable_plugins: true
    }
    if previous_reservation
      previous_reservation_attributes = previous_reservation.reusable_attributes
      new_reservation_attributes.merge!(previous_reservation_attributes)
    end

    filtered_params = params.except(:ip)
    permitted_params = filtered_params.permit([ :authenticity_token, :whitelist_type, :api_key, :steam_uid, { reservation: %i[starts_at ends_at server_id password rcon tv_password enable_plugins enable_demos_tf auto_end first_map server_config_id whitelist_id custom_whitelist_id democheck_mode] } ])
    new_reservation_attributes.merge!(permitted_params[:reservation]) if permitted_params[:reservation]

    current_user.reservations.build(new_reservation_attributes)
  end

  sig { returns(ActiveRecord::Relation) }
  def free_servers
    T.bind(self, T.untyped)
    @free_servers ||= begin
      return Server.none if free_server_limit_reached_for_reservation?

      if current_user.geocoded?
        servers = free_server_finder.servers
        geocoded_servers = servers.geocoded.near(current_user, 50_000)
        non_geocoded_servers = servers.where(latitude: nil)
        (geocoded_servers.or(non_geocoded_servers)).order(Arel.sql("CASE WHEN latitude IS NULL THEN 1 ELSE 0 END, distance, position, name"))
      else
        free_server_finder.servers.order(:position, :name)
      end
    end
  end

  sig { returns(T.untyped) }
  def free_docker_hosts
    T.bind(self, T.untyped)
    @free_docker_hosts ||= begin
      return [] if free_server_limit_reached_for_reservation?

      s = @reservation.starts_at || Time.current
      e = @reservation.ends_at || 2.hours.from_now
      DockerHost.available_during(s, e)
    end
  end

  sig { returns(T::Boolean) }
  def free_server_limit_reached_for_reservation?
    T.bind(self, T.untyped)
    return false unless current_user

    s = @reservation&.starts_at || Time.current
    e = @reservation&.ends_at || 2.hours.from_now
    SiteSetting.free_server_limit_reached?(current_user, s, e)
  end

  sig { returns(String) }
  def free_servers_json
    T.bind(self, T.untyped)
    servers_json = free_servers.map do |s|
      { id: s.id, text: s.name, flag: s.location_flag, ip: s.ip, ip_and_port: "#{s.public_ip}:#{s.public_port}" }
    end

    docker_hosts_json = free_docker_hosts.map do |dh|
      { id: "dh-#{dh.id}", text: "#{dh.city} (#{dh.hostname})", flag: dh.location&.flag, ip: dh.hostname, ip_and_port: "#{dh.hostname}:#{dh.start_port}" }
    end

    (docker_hosts_json + servers_json).to_json
  end

  sig { returns(T.untyped) }
  def free_server_finder
    T.bind(self, T.untyped)
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

  sig { returns(T.untyped) }
  def cancel_reservation
    T.bind(self, T.untyped)
    flash[:notice] = "Reservation for #{@reservation} cancelled"
    reservation.destroy
  end

  sig { returns(String) }
  def end_reservation
    T.bind(self, T.untyped)
    reservation.update_attribute(:end_instantly, true)
    reservation.end_reservation
    link = "/uploads/#{reservation.zipfile_name}"
    flash[:notice] = "Reservation removed, restarting server. Your STV demos and logs will be available <a href='#{link}' target=_blank>here</a> soon".html_safe
  end

  sig { returns(T.nilable(Reservation)) }
  def previous_reservation
    T.bind(self, T.untyped)
    current_user.reservations.last
  end

  private

  sig { returns(ActionController::Parameters) }
  def reservation_params
    T.bind(self, T.untyped)
    permitted_params = %i[id password tv_password tv_relaypassword server_config_id whitelist_id custom_whitelist_id first_map auto_end enable_plugins enable_demos_tf democheck_mode]
    permitted_params += %i[rcon server_id starts_at ends_at] if reservation.nil? || reservation&.schedulable?
    params.require(:reservation).permit(permitted_params)
  end

  sig { returns(ActiveSupport::TimeWithZone) }
  def starts_at
    T.bind(self, T.untyped)
    raw = (params[:reservation] && params[:reservation][:starts_at].presence) || params[:starts_at].presence
    parsed = raw && Time.zone.parse(raw) rescue nil
    if parsed && parsed >= Time.current
      parsed
    else
      Time.current
    end
  end

  sig { returns(T.untyped) }
  def ends_at
    T.bind(self, T.untyped)
    (params[:reservation] && params[:reservation][:ends_at].presence) || params[:ends_at].presence || 2.hours.from_now
  end

  sig { returns(ActionController::Parameters) }
  def template_params
    T.bind(self, T.untyped)
    params.permit(*Reservation.template_attribute_names)
  end
end
