class ServersNotificationWorker
  include Sidekiq::Worker
  include Sidetiq::Schedulable

  recurrence { hourly.minute_of_hour(0, 20, 40) }

  def perform
    reservation_ids.each do |reservation_id|
      ServerNotificationWorker.perform_async(reservation_id)
    end
  end

  def reservation_ids
    Reservation.current.pluck(:id)
  end

end
