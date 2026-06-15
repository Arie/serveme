# typed: true
# frozen_string_literal: true

class AnnouncePlayerWorker
  include Sidekiq::Worker
  extend T::Sig
  sidekiq_options retry: false

  sig { params(reservation_id: T.nilable(Integer), steam_uid: Integer, ip: String).void }
  def perform(reservation_id, steam_uid, ip)
    reservation = Reservation.find_by(id: reservation_id)
    return unless reservation&.server
    return if ReservationPlayer.where(steam_uid: steam_uid).exists?

    info = PlayerAnnouncementService.build_info(steam_uid, ip)

    reservation.server&.rcon_say("#{steam_uid}: #{info}")
    reservation.server&.rcon_disconnect
  end
end
