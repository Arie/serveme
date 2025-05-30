# typed: true
# frozen_string_literal: true

class ServerNotificationWorker
  include Sidekiq::Worker

  sidekiq_options retry: 3

  def perform(reservation_id)
    reservation = Reservation.includes(:user, :server).find(reservation_id)
    send_notification(reservation)
  end

  def send_notification(reservation)
    return if reservation.user.donator?

    notification = notifications_for_non_donators.sample
    return unless notification

    reservation&.server&.rcon_say(notification.message.gsub("%{name}", reservation.user.nickname || reservation.user.uid))
    reservation&.server&.rcon_disconnect
  end

  def notifications_for_non_donators
    @notifications_for_non_donators ||= ServerNotification.for_everyone + ServerNotification.ads
  end
end
