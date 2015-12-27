# frozen_string_literal: true
class ServersNotificationWorker
  include Sidekiq::Worker

  def perform
    reservation_ids.each do |reservation_id|
      ServerNotificationWorker.perform_async(reservation_id)
    end
  end

  def reservation_ids
    Reservation.current.pluck(:id)
  end

end
