# typed: true
# frozen_string_literal: true

module Api
  class ReservationsController < Api::ApplicationController
    include ReservationsHelper

    def index
      limit = params[:limit] || 10
      limit = [ limit.to_i, 500 ].min
      @reservations = reservations_scope.includes(:reservation_statuses, :server_statistics, server: :location).order(id: :desc).limit(limit).offset(params[:offset].to_i)
    end

    def new
      @reservation = new_reservation
    end

    def show
      @reservation = reservation
    end

    def find_servers
      @reservation = new_reservation
      @servers = free_servers.where(sdr: false)
      @docker_hosts = free_docker_hosts
      render :find_servers
    end

    def create
      server_id = reservation_params[:server_id]

      if server_id.present? && DockerHost.docker_host_id?(server_id)
        create_docker_host_reservation(server_id)
      else
        create_regular_reservation
      end
    end

    def update
      reservation.update(reservation_params)
      if reservation.errors.any?
        Rails.logger.warn "API: User: #{api_user.nickname} - Validation errors: #{reservation.errors.full_messages.join(', ')}"
        render :show, status: :bad_request
      else
        ReservationChangesWorker.perform_async(reservation.id, reservation.previous_changes.to_json)
        render :show
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

    def extend
      if reservation.extend!
        render :show
      else
        render :show, status: :bad_request
      end
    end

    private

    def reservations_scope
      if api_user.admin? || api_user.trusted_api?
        if params[:steam_uid]
          Reservation.joins(:user).where(users: { uid: params[:steam_uid] })
        else
          Reservation.joins(:user)
        end
      else
        current_user.reservations.joins(:user)
      end
    end

    def reservation
      @reservation ||= reservations_scope.find(params[:id])
    end

    def create_regular_reservation
      @reservation = current_user.reservations.build(reservation_params)
      if @reservation.valid?
        $lock.synchronize("save-reservation-server-#{@reservation.server_id}") do
          @reservation.save!
        end
        if @reservation.persisted? && @reservation.now?
          @reservation.update_attribute(:start_instantly, true)
          @reservation.start_reservation
        end
        render :show
      else
        Rails.logger.warn "API: User: #{api_user.nickname} - Validation errors: #{@reservation.errors.full_messages.join(', ')}"
        @servers = free_servers
        render :find_servers, status: :bad_request
      end
    end

    def create_docker_host_reservation(virtual_server_id)
      docker_host_id = virtual_server_id.to_i - DockerHost::VIRTUAL_ID_OFFSET
      creator = DockerHostReservationCreator.new(
        user: current_user,
        docker_host_id: docker_host_id,
        reservation_params: reservation_params
      )
      @reservation = creator.create!
      render :show
    rescue DockerHostReservationCreator::CapacityError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue DockerHostReservationCreator::ValidationError => e
      @reservation = e.reservation
      @servers = free_servers
      render :find_servers, status: :bad_request
    end

    def reservation_params
      params.require(:reservation).permit(:starts_at, :ends_at, :server_id, :rcon, :password, :first_map, :tv_password, :tv_relaypassword, :server_config_id, :whitelist_id, :custom_whitelist_id, :auto_end, :enable_plugins, :enable_demos_tf, :disable_democheck)
    end
  end
end
