# frozen_string_literal: true

class ApplyApiKeysWorker
  include Sidekiq::Worker

  sidekiq_options retry: 2

  def perform(reservation_id)
    reservation = Reservation.find(reservation_id)

    return unless reservation.server

    reservation.apply_api_keys
  end
end
