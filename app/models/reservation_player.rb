# frozen_string_literal: true

class ReservationPlayer < ActiveRecord::Base
  belongs_to :reservation
  has_one :server, through: :reservation, autosave: false
  belongs_to :user, primary_key: :uid, foreign_key: :steam_uid

  geocoded_by :ip
  before_save :geocode, if: :ip_changed?

  def self.banned?(steam_profile)
    banned_name?(steam_profile&.nickname) || banned_uid?(steam_profile&.steam_id64)
  end

  def self.banned_name?(nickname)
    nickname.include?('﷽')
  end

  def self.banned_uid?(steam_id64)
    [
      76_561_198_243_188_782, # Paypal fraud
      76_561_198_310_925_535, 76_561_199_116_364_920, 76_561_198_113_294_936, # Clx
      76_561_198_248_413_054, 76_561_197_963_634_600, 76_561_197_996_867_869, 76_561_199_111_424_250, # Gremlin
      76_561_198_035_013_366, 76_561_198_114_767_457 # Nino
    ].include?(steam_id64.to_i)
  end

  def self.banned_ip?(ip)
    ip.start_with?('82.222.')
  end
end
