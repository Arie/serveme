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
    nickname.include?("﷽")
  end

  def self.banned_uid?(steam_id64)
    [
      76_561_198_310_925_535, 76_561_199_116_364_920 # Clx
    ].include?(steam_id64.to_i)
  end
end
