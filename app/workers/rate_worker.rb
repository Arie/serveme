class RateWorker
  include Sidekiq::Worker

  sidekiq_options :retry => false

  attr_accessor :reservation_id, :rating, :sayer_steam_uid, :sayer_name

  def perform(reservation_id, sayer_steam_uid, sayer_name, message)
    @reservation_id = reservation_id
    @sayer_steam_uid = sayer_steam_uid
    @sayer_name = sayer_name
    rating.parse_message!(message)
  end

  def rating
    @rating ||= Rating.where(:reservation_id => reservation_id, :steam_uid => sayer_steam_uid, :nickname => sayer_name).first_or_initialize
  end

end
