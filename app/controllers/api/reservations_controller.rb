class Api::ReservationsController < Api::ApplicationController

  include ReservationsHelper

  def new
    @reservation = Reservation.new
  end

  def show
    @reservation = reservation
  end

  def find_servers
    find_servers_for_user
  end

  def create
    @reservation = current_user.reservations.build(reservation_params)
    if @reservation.save
      if @reservation.now?
        @reservation.update_attribute(:start_instantly, true)
        @reservation.start_reservation
      end
      render :show
    else
      Rails.logger.warn "API: User: #{api_user.nickname} - Validation errors: #{@reservation.errors.full_messages.join(", ")}"
      @servers = free_servers
      render :find_servers, :status => :bad_request
    end
  end

  def destroy
    if reservation.cancellable?
      reservation.destroy
      head :no_content
    else
      reservation.update_attribute(:end_instantly, true)
      reservation.end_reservation
      render :show
    end
  end

  private

  def reservation
    @reservation ||= current_user.reservations.find(params[:id])
  end

  def reservation_params
    params.require(:reservation).permit(:starts_at, :ends_at, :server_id, :rcon, :password, :first_map, :tv_password, :tv_relaypassword, :server_config_id, :whitelist_id, :custom_whitelist_id, :auto_end)
  end

end
