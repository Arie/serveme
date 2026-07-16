# typed: true
# frozen_string_literal: true

class ReservationTransitionWorker
  include Sidekiq::Worker

  ALLOWED_ACTIONS = %w[start end].freeze

  sidekiq_options retry: false, queue: "priority"

  def perform(reservation_id, action)
    raise ArgumentError, "Invalid action: #{action}" unless ALLOWED_ACTIONS.include?(action)

    reservation = Reservation.find(reservation_id)
    reservation.public_send("#{action}_reservation")
  end
end
