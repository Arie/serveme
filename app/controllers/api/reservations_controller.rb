# typed: true
# frozen_string_literal: true

module Api
  class ReservationsController < Api::ApplicationController
    include ReservationsHelper
    before_action :map_legacy_democheck_param, only: [ :create, :update ]

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
      starts_at = reservation_params[:starts_at].present? ? Time.zone.parse(reservation_params[:starts_at].to_s) : Time.current
      ends_at = reservation_params[:ends_at].present? ? Time.zone.parse(reservation_params[:ends_at].to_s) : 2.hours.from_now
      if SiteSetting.free_server_limit_reached?(current_user, starts_at, ends_at)
        render json: { error: "All free servers are currently in use. Try again later or get premium for more servers." }, status: :unprocessable_entity
        return
      end

      server_id = reservation_params[:server_id]

      if server_id.present? && DockerHost.docker_host_id?(server_id)
        create_docker_host_reservation(server_id)
      else
        create_regular_reservation
      end
    end

    def update
      writable_reservation.update(reservation_params)
      if writable_reservation.errors.any?
        Rails.logger.warn "API: User: #{api_user.nickname} - Validation errors: #{writable_reservation.errors.full_messages.join(', ')}"
        @reservation = writable_reservation
        render :show, status: :bad_request
      else
        @reservation = writable_reservation
        ReservationChangesWorker.perform_async(writable_reservation.id, writable_reservation.previous_changes.to_json)
        render :show
      end
    rescue ActiveRecord::RecordNotUnique
      writable_reservation.errors.add(:server_id, "already booked in the selected timeframe")
      @reservation = writable_reservation
      render :show, status: :bad_request
    end

    def destroy
      if writable_reservation.cancellable?
        writable_reservation.destroy
        head :no_content
      else
        writable_reservation.update_attribute(:end_instantly, true)
        writable_reservation.end_reservation
        @reservation = writable_reservation
        render :show
      end
    end

    def extend
      if writable_reservation.extend!
        @reservation = writable_reservation
        render :show
      else
        @reservation = writable_reservation
        render :show, status: :bad_request
      end
    end

    private

    def reservations_scope
      if api_user.admin? || api_user.league_admin? || api_user.streamer? || api_user.trusted_api?
        if params[:steam_uid]
          Reservation.joins(:user).where(users: { uid: params[:steam_uid] })
        else
          Reservation.joins(:user)
        end
      else
        current_user.reservations.joins(:user)
      end
    end

    def writable_reservations_scope
      if api_user.admin? || api_user.league_admin? || api_user.trusted_api?
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

    def writable_reservation
      @writable_reservation ||= writable_reservations_scope.find(params[:id])
    end

    def create_regular_reservation
      @reservation = current_user.reservations.build(reservation_params)
      if @reservation.valid?
        $lock.synchronize("save-reservation-server-#{@reservation.server_id}") do
          if @reservation.valid?
            @reservation.save!
          end
        end
      end
      if @reservation.persisted?
        if @reservation.now?
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
      params.require(:reservation).permit(:starts_at, :ends_at, :server_id, :rcon, :password, :first_map, :tv_password, :tv_relaypassword, :server_config_id, :whitelist_id, :custom_whitelist_id, :auto_end, :enable_plugins, :enable_demos_tf, :disable_democheck, :democheck_mode)
    end

    def map_legacy_democheck_param
      return unless params[:reservation]
      return if params[:reservation][:democheck_mode].present?
      return unless params[:reservation].key?(:disable_democheck)

      params[:reservation][:democheck_mode] = ActiveModel::Type::Boolean.new.cast(params[:reservation][:disable_democheck]) ? "disable" : "kick"
      params[:reservation].delete(:disable_democheck)
    end
  end
end
