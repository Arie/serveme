# frozen_string_literal: true

class ReservationPlayer < ActiveRecord::Base
  require 'ipaddr'
  belongs_to :reservation
  has_one :server, through: :reservation, autosave: false
  belongs_to :user, primary_key: :uid, foreign_key: :steam_uid

  geocoded_by :ip
  before_save :geocode, if: :ip_changed?

  def duplicates
    self.class.where(reservation_id: reservation_id).where(steam_uid: steam_uid).where(ip: ip)
  end

  def self.whitelisted
    where(whitelisted: true)
  end

  def self.banned?(steam_profile)
    (banned_name?(steam_profile&.nickname) || banned_uid?(steam_profile&.steam_id64)) && !whitelisted_uid?(steam_profile&.steam_id64)
  end

  def self.banned_name?(nickname)
    nickname.include?('﷽')
  end

  def self.whitelisted_uid?(steam_id64)
    return true unless steam_id64

    [
      76_561_198_194_941_135, # Despair, shares ISP with Gremlin
      76_561_198_253_170_562, # Shock, shares ISP with Gremlin
      76_561_198_378_191_199, # Sori666, shares ISP with Gremlin
      76_561_198_360_811_196, # Sun Tzu, shares ISP with Clx
      76_561_198_238_943_688, # Flewvar, shares ISP with Clx
      76_561_198_167_849_935, # Laggy Lanny, shares IP with Gremlin
      76_561_198_210_526_425  # Still, shares IP with Gremlin
    ].include?(steam_id64.to_i)
  end

  def self.banned_uid?(steam_id64)
    [
      76_561_198_310_925_535, 76_561_199_116_364_920, 76_561_198_113_294_936, # Clx
      76_561_199_165_871_973, 76_561_199_164_609_965, 76_561_199_164_115_386, 76_561_199_146_255_686, # Clx
      76_561_199_166_660_740, 76_561_199_135_772_351, # Clx
      76_561_198_156_399_565, # Possible Clx alt
      76_561_198_280_266_851, # Clx leaker Bread
      76_561_197_964_387_679, # 0x0258deaD DDoSer
      76_561_199_186_114_313, # Impersonating serveme.tf personnel
      76_561_199_062_609_974, 76_561_198_238_170_280, 76_561_199_208_354_375, 76_561_199_199_088_995, # Cheeto match invader
      76_561_198_091_464_403, 76_561_199_132_066_910, 76_561_197_962_267_804, 76_561_199_200_781_287, # Cheeto match invader
      76_561_198_347_491_669 # Cheeto match invader
    ].include?(steam_id64.to_i)
  end

  def self.banned_ip?(ip)
    banned_ranges.any? { |range| range.include?(ip) }
  end

  def self.banned_ranges
    @banned_ranges ||= [
      IPAddr.new('107.181.180.0/24'), # Clx
      IPAddr.new('162.253.68.0/22'), # Clx
      IPAddr.new('82.222.236.0/22'), # Clx
      IPAddr.new('46.166.176.0/21'), # Clx
      IPAddr.new('45.89.173.0/24'), # Clx
      IPAddr.new('24.133.100.0/22'), # Bread
      IPAddr.new('176.40.96.0/21'), # 0x0258deaD DDoSer
      IPAddr.new('69.247.46.46/32'), # Cheeto match invader
      IPAddr.new('198.54.128.0/24'), # Cheeto match invader
      IPAddr.new('45.134.142.0/24'), # Cheeto match invader
      IPAddr.new('94.198.42.0/24'), # Cheeto match invader
      IPAddr.new('193.27.12.0/24') # Cheeto match invader
    ]
  end

  def self.banned_country?(ip)
    geocode_result = Geocoder.search(ip).first
    return false unless geocode_result

    %w[BY RU].include?(geocode_result.country_code)
  end
end
