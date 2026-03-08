# typed: false
# frozen_string_literal: true

class CloudReservationsController < ApplicationController
  before_action :require_cloud_access
  before_action :check_concurrent_cloud_limit, only: :create

  def new
    attributes = {
      starts_at: Time.current,
      ends_at: 2.hours.from_now,
      password: FriendlyPasswordGenerator.generate,
      rcon: SecureRandom.hex(4),
      enable_plugins: true,
      auto_end: true
    }

    previous = current_user.reservations.last
    if previous
      attributes.merge!(previous.reusable_attributes.except("server_id").symbolize_keys)
    end

    @reservation = current_user.reservations.build(attributes)
    @cloud_locations = CloudProvider.grouped_locations(user: current_user)
    @server_configs = ServerConfig.active.ordered
  end

  def available_locations
    starts_at = params[:starts_at].present? ? Time.zone.parse(params[:starts_at].to_s) : Time.current
    ends_at = params[:ends_at].present? ? Time.zone.parse(params[:ends_at].to_s) : 2.hours.from_now
    @cloud_locations = CloudProvider.grouped_locations(starts_at: starts_at, ends_at: ends_at, user: current_user)
    render json: @cloud_locations
  end

  def create
    provider_name, location_code = params[:cloud_location].to_s.split(":", 2)

    begin
      server = CloudServer.build_for_location(provider_name, location_code, rcon: params[:reservation][:rcon])
    rescue ArgumentError
      flash[:alert] = "Invalid cloud location."
      redirect_to new_cloud_reservation_path
      return
    end

    lock_key = if provider_name == "remote_docker"
                 "cloud-reservation-docker-host-#{location_code}"
    else
                 "cloud-reservation-user-#{current_user.id}"
    end

    $lock.synchronize(lock_key, retries: 5, initial_wait: 0.1, expiry: 30) do
      if provider_name == "remote_docker"
        docker_host = DockerHost.find_by(id: location_code)
        starts_at = params[:reservation][:starts_at].present? ? Time.zone.parse(params[:reservation][:starts_at].to_s) : Time.current
        ends_at = params[:reservation][:ends_at].present? ? Time.zone.parse(params[:reservation][:ends_at].to_s) : 2.hours.from_now
        if docker_host&.full_during?(starts_at, ends_at)
          flash[:alert] = "This location is at full capacity for the selected time. Please choose another."
          redirect_to new_cloud_reservation_path
          return
        end
      end

      server.save!

      @reservation = current_user.reservations.build(reservation_params)
      @reservation.server = server
      future_start = params[:reservation][:starts_at].present? && Time.zone.parse(params[:reservation][:starts_at].to_s)&.future?
      @reservation.starts_at = future_start ? params[:reservation][:starts_at] : Time.current
      @reservation.ends_at = params[:reservation][:ends_at].present? ? params[:reservation][:ends_at] : 2.hours.from_now

      if @reservation.save
        server.update!(cloud_reservation_id: @reservation.id, name: "#{server.name} ##{@reservation.id}")
        if future_start && @reservation.starts_at > 5.minutes.from_now
          CloudServerProvisionWorker.perform_at(@reservation.starts_at - 5.minutes, server.id)
          flash[:notice] = "Cloud server is scheduled. Provisioning will begin 5 minutes before your start time (#{I18n.l(@reservation.starts_at, format: :short)})."
        else
          CloudServerProvisionWorker.perform_async(server.id)
          flash[:notice] = "Cloud server is being provisioned. This usually takes #{server.provider.estimated_provision_time}."
        end
        redirect_to reservation_path(@reservation)
      else
        server.destroy
        @cloud_locations = CloudProvider.grouped_locations(user: current_user)
        @server_configs = ServerConfig.active.ordered
        render :new, status: :unprocessable_entity
      end
    end
  rescue RemoteLock::Error
    flash[:alert] = "Server is busy, please try again."
    redirect_to new_cloud_reservation_path
  end

  private

  def require_cloud_access
    return if current_user&.can_use_cloud_servers?

    flash[:alert] = "Cloud servers are available to Premium users."
    redirect_to root_path
  end

  def check_concurrent_cloud_limit
    return if docker_provider_selected?

    active = current_user.active_cloud_reservation
    return unless active

    flash[:alert] = "You already have an active cloud server. Please end it before launching another."
    redirect_to reservation_path(active)
  end

  def docker_provider_selected?
    provider_name, = params[:cloud_location].to_s.split(":", 2)
    provider_name.in?(%w[docker remote_docker])
  end

  def reservation_params
    params.require(:reservation).permit(
      :password, :rcon, :first_map, :enable_plugins, :enable_demos_tf,
      :auto_end, :server_config_id, :whitelist_id, :custom_whitelist_id,
      :tv_password, :starts_at, :ends_at
    )
  end
end
