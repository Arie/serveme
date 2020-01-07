# frozen_string_literal: true

class ActiveReservationsCheckerWorker
  include Sidekiq::Worker

  def perform(reservation_ids)
    reservation_ids.each do |reservation_id|
      ActiveReservationCheckerWorker.perform_async(reservation_id)
    end
  end
end
