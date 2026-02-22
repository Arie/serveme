# typed: false
# frozen_string_literal: true

class CloudReservationsController < ApplicationController
  before_action :require_admin_or_streamer

  def new
    @reservation = current_user.reservations.build(
      starts_at: Time.current,
      ends_at: 2.hours.from_now,
      password: FriendlyPasswordGenerator.generate,
      rcon: SecureRandom.hex(4),
      enable_plugins: true,
      auto_end: true
    )
    @cloud_locations = CloudProvider.grouped_locations
    @server_configs = ServerConfig.active.ordered
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

    server.save!

    @reservation = current_user.reservations.build(reservation_params)
    @reservation.server = server
    @reservation.starts_at = Time.current
    @reservation.ends_at = params[:reservation][:ends_at].present? ? params[:reservation][:ends_at] : 2.hours.from_now

    if @reservation.save
      server.update!(cloud_reservation_id: @reservation.id, name: "#{server.name} ##{@reservation.id}")
      CloudServerProvisionWorker.perform_async(server.id)
      flash[:notice] = "Cloud server is being provisioned. This usually takes #{server.provider.estimated_provision_time}."
      redirect_to reservation_path(@reservation)
    else
      server.destroy
      @cloud_locations = CloudProvider.grouped_locations
      @server_configs = ServerConfig.active.ordered
      render :new, status: :unprocessable_entity
    end
  end

  private

  def reservation_params
    params.require(:reservation).permit(
      :password, :rcon, :first_map, :enable_plugins, :enable_demos_tf,
      :auto_end, :server_config_id, :whitelist_id, :custom_whitelist_id,
      :tv_password, :ends_at
    )
  end
end
