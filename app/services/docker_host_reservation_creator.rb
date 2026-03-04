# typed: false
# frozen_string_literal: true

class DockerHostReservationCreator
  attr_reader :user, :docker_host_id, :reservation_params

  def initialize(user:, docker_host_id:, reservation_params:)
    @user = user
    @docker_host_id = docker_host_id
    @reservation_params = reservation_params
  end

  def create!
    $lock.synchronize("cloud-reservation-docker-host-#{docker_host_id}", retries: 5, initial_wait: 0.1, expiry: 30) do
      docker_host = DockerHost.find(docker_host_id)
      starts_at = reservation_params[:starts_at].present? ? Time.zone.parse(reservation_params[:starts_at].to_s) : Time.current
      ends_at = reservation_params[:ends_at].present? ? Time.zone.parse(reservation_params[:ends_at].to_s) : 2.hours.from_now

      if docker_host.full_during?(starts_at, ends_at)
        raise CapacityError, "This location is at full capacity for the selected time. Please choose another server."
      end

      cloud_server = CloudServer.build_for_location("remote_docker", docker_host_id.to_s, rcon: reservation_params[:rcon])
      cloud_server.save!

      reservation = user.reservations.build(reservation_params.except(:server_id))
      reservation.server = cloud_server
      future_start = reservation_params[:starts_at].present? && Time.zone.parse(reservation_params[:starts_at].to_s)&.future?
      reservation.starts_at = future_start ? reservation_params[:starts_at] : Time.current
      reservation.ends_at = ends_at

      if reservation.save
        cloud_server.update!(cloud_reservation_id: reservation.id, name: "#{cloud_server.name} ##{reservation.id}")
        schedule_provisioning(cloud_server, reservation, future_start)
        reservation
      else
        cloud_server.destroy
        raise ValidationError.new("Reservation invalid", reservation)
      end
    end
  rescue RemoteLock::Error
    raise CapacityError, "Server is busy, please try again."
  end

  class CapacityError < StandardError; end

  class ValidationError < StandardError
    attr_reader :reservation

    def initialize(message, reservation)
      @reservation = reservation
      super(message)
    end
  end

  private

  def schedule_provisioning(cloud_server, reservation, future_start)
    if future_start && reservation.starts_at > 5.minutes.from_now
      CloudServerProvisionWorker.perform_at(reservation.starts_at - 5.minutes, cloud_server.id)
    else
      CloudServerProvisionWorker.perform_async(cloud_server.id)
    end
  end
end
