# typed: true
# frozen_string_literal: true

class ReservationChangesWorker
  include Sidekiq::Worker

  attr_reader :reservation

  def perform(reservation_id, changed_attributes)
    @reservation = Reservation.find(reservation_id)

    if reservation.now?
      reservation.server.update_configuration(reservation)

      if changed_attributes.include?("first_map") && changed_attributes.include?("server_config_id")
        reservation.server.rcon_exec("servercfgfile server.cfg; exec reservation.cfg; changelevel #{reservation.first_map}")
      elsif changed_attributes.include?("first_map")
        reservation.server.rcon_exec("servercfgfile server.cfg; changelevel #{reservation.first_map}")
      else
        reservation.server.rcon_exec("exec reservation.cfg")
      end
    end
  end
end
