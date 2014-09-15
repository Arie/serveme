class RateWorker
  include Sidekiq::Worker

  sidekiq_options :retry => false

  attr_accessor :reservation_id, :rating, :sayer_steam_uid, :sayer_name

  def perform(reservation_id, sayer_steam_uid, sayer_name, message)
    message = message.split(" ")
    return unless ["good", "bad"].include?(message[1].to_s)
    @reservation_id = reservation_id
    @sayer_steam_uid = sayer_steam_uid
    @sayer_name = sayer_name
    rating.parse_message!(message)
    reservation.server.rcon_say "Thanks for rating this server #{sayer_name}"
    Rails.logger.info "#{sayer_name} rated server #{reservation.server.name}: #{message[1..-1]} from chat"
  end

  def rating
    @rating ||= Rating.where(:reservation_id => reservation_id, :steam_uid => sayer_steam_uid, :nickname => sayer_name).first_or_initialize
  end

  def reservation
    @reservation ||= Reservation.find(reservation_id)
  end

end
