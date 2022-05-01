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
      76561198194941135, # Despair, shares ISP with Gremlin
      76561198253170562, # Shock, shares ISP with Gremlin
      76561198378191199, # Sori666, shares ISP with Gremlin
      76561198360811196, # Sun Tzu, shares ISP with Clx
      76561198238943688, # Flewvar, shares ISP with Clx
      76561198167849935, # Laggy Lanny, shares IP with Gremlin
      76561198210526425  # Still, shares IP with Gremlin
    ].include?(steam_id64.to_i)
  end

  def self.banned_uid?(steam_id64)
    [
      76561198310925535, 76561199116364920, 76561198113294936, # Clx
      76561199165871973, 76561199164609965, 76561199164115386, 76561199146255686, # Clx
      76561199166660740, 76561199135772351, # Clx
      76561198156399565, # Possible Clx alt
      76561198280266851, # Clx leaker Bread
      76561197964387679, # 0x0258deaD DDoSer
      76561199186114313, # Impersonating serveme.tf personnel
      76561199062609974, 76561198238170280, 76561199208354375, 76561199199088995, # Cheeto match invader
      76561198091464403, 76561199132066910, 76561197962267804, 76561199200781287, # Cheeto match invader
      76561198347491669, # Cheeto match invader
      76561199251574288, 76561198091464403, # semiperf log spammer
      76561198167446102, 76561198081019811, 76561199129719751, 76561199178857855, 76561199133700932 # sandstoner log spammer
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
      IPAddr.new('193.27.12.0/24'), # Cheeto match invader
      IPAddr.new('75.131.150.35/32'), # semiperf log spammer
      IPAddr.new('68.116.180.185/32'), # semiperf log spammer
      IPAddr.new('75.131.148.146/32'), # semiperf log spammer
      IPAddr.new('73.55.161.142/32') # sandstoner log spammer
    ]
  end

  def self.banned_country?(ip)
    geocode_result = Geocoder.search(ip).first
    return false unless geocode_result

    %w[BY RU].include?(geocode_result.country_code)
  end
end
