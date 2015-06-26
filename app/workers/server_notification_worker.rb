class ServerNotificationWorker
  include Sidekiq::Worker

  sidekiq_options :retry => 3

  def perform(reservation_id)
    reservation = Reservation.includes(:user, :server).find(reservation_id)
    send_notification(reservation)
  end

  def send_notification(reservation)
    unless reservation.user.donator?
      notification = notifications_for_non_donators.sample
      reservation.server.rcon_say(notification.message.gsub("%{name}", reservation.user.nickname)) if notification
    end
  end

  def notifications_for_non_donators
    @notifications_for_non_donators ||= ServerNotification.for_everyone + ServerNotification.ads
  end

end
