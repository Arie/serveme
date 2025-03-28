# typed: true
# frozen_string_literal: true

class ReservationChangesWorker
  include Sidekiq::Worker

  attr_reader :reservation

  def perform(reservation_id, changes)
    @reservation = Reservation.find(reservation_id)

    if reservation.now?
      reservation.server.update_configuration(reservation)

      if changes["first_map"] && changes["server_config_id"]
        reservation.server.rcon_exec("servercfgfile server.cfg; exec reservation.cfg; changelevel #{reservation.first_map}")
      elsif changes["first_map"]
        reservation.server.rcon_exec("changelevel #{reservation.first_map}")
      else
        reservation.server.rcon_exec("exec reservation.cfg")
      end
    end
  end
end
