class ServerNotificationWorker
  include Sidekiq::Worker
  include Sidetiq::Schedulable

  recurrence { hourly.minute_of_hour(0, 20, 40) }

  def perform
    reservations.each do |reservation|
      send_notification(reservation)
    end
  end

  def send_notification(reservation)
    if reservation.user.donator?
      notification = notifications_for_donators.sample
    else
      notification = notifications_for_non_donators.sample
    end
    reservation.server.set_logaddress
    reservation.server.rcon_say(notification.message) if notification
  end

  def notifications_for_donators
    @notifications_for_donators ||= notifications
  end

  def notifications_for_non_donators
    @notifications_for_non_donators ||= notifications + ads
  end

  def notifications
    ServerNotification.where(:ad => false)
  end

  def ads
    ServerNotification.where(:ad => true)
  end

  def reservations
    Reservation.includes(:user, :server).current
  end

end
