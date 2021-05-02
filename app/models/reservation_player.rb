# frozen_string_literal: true

class ReservationPlayer < ActiveRecord::Base
  require 'ipaddr'
  belongs_to :reservation
  has_one :server, through: :reservation, autosave: false
  belongs_to :user, primary_key: :uid, foreign_key: :steam_uid

  geocoded_by :ip
  before_save :geocode, if: :ip_changed?

  def self.banned?(steam_profile)
    (banned_name?(steam_profile&.nickname) || banned_uid?(steam_profile&.steam_id64)) && !whitelisted_uid?(steam_profile&.steam_id64)
  end

  def self.banned_name?(nickname)
    nickname.include?('﷽')
  end

  def self.whitelisted_uid?(steam_id64)
    return true unless steam_id64

    [
      76_561_198_360_811_196, # Sun Tzu, shares ISP with Clx
      76_561_198_238_943_688 # Flewvar, shares ISP with Clx
    ].include?(steam_id64.to_i)
  end

  def self.banned_uid?(steam_id64)
    [
      76_561_198_243_188_782, # Paypal fraud
      76_561_198_310_925_535, 76_561_199_116_364_920, 76_561_198_113_294_936, # Clx
      76_561_199_165_871_973, 76_561_199_164_609_965, 76_561_199_164_115_386, 76_561_199_146_255_686, # Clx
      76_561_199_166_660_740, # Clx
      76_561_198_280_266_851, # Clx leaker Bread
      76_561_198_248_413_054, 76_561_197_963_634_600, 76_561_197_996_867_869, 76_561_199_111_424_250, # Gremlin
      76_561_198_035_013_366, 76_561_198_114_767_457 # Nino
    ].include?(steam_id64.to_i)
  end

  def self.banned_ip?(ip)
    banned_ranges.any? do |range|
      range.include?(ip)
    end
  end

  def self.banned_ranges
    @banned_ranges ||= [
      IPAddr.new('107.181.180.0/24'), # Clx
      IPAddr.new('162.253.68.0/22'), # Clx
      IPAddr.new('82.222.236.0/22'), # Clx
      IPAddr.new('46.166.176.0/21'), # Clx
      IPAddr.new('24.133.100.0/22') # Blead
    ]
  end
end
