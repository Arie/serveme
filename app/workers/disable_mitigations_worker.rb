# frozen_string_literal: true

class DisableMitigationsWorker
  include Sidekiq::Worker

  sidekiq_options retry: 10

  attr_accessor :reservation, :reservation_id

  def perform(reservation_id)
    @reservation_id = reservation_id
    @reservation = Reservation.includes(:server).find(reservation_id)
    reservation.disable_mitigations
  end
end
