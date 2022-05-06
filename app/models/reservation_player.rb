# frozen_string_literal: true

class ReservationPlayer < ActiveRecord::Base
  require 'csv'
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

    whitelisted_uids.include?(steam_id64.to_i)
  end

  def self.whitelisted_uids
    @whitelisted_uids ||= CSV.read(Rails.root.join('doc', 'whitelisted_steam_ids.csv'), headers: true).map { |row| row['steam_id64'].to_i }
  end

  def self.banned_uid?(steam_id64)
    banned_uids.include?(steam_id64)
  end

  def self.banned_ip?(ip)
    banned_ranges.any? { |range| range.include?(ip) }
  end

  def self.banned_uids
    @banned_uids ||= CSV.read(Rails.root.join('doc', 'banned_steam_ids.csv'), headers: true).map { |row| row['steam_id64'].to_i }
  end

  def self.banned_ranges
    @banned_ranges ||= CSV.read(Rails.root.join('doc', 'banned_ips.csv'), headers: true).map { |row| IPAddr.new(row['ip']) }
  end

  def self.banned_asn?(ip)
    asn = $maxmind_asn.asn(ip)&.autonomous_system_number
    asn && (banned_asns.include?(asn) || custom_banned_asns.include?(asn))
  end

  def self.banned_asns
    @banned_asns ||= CSV.read(Rails.root.join('doc', 'bad-asn-list.csv'), headers: true).map { |row| row['ASN'].to_i }
  end

  def self.custom_banned_asns
    [
      212238, # Datacamp
      397423, # Tier.net
      46844 # Sharktech.net
    ]
  end

  def self.banned_country?(ip)
    geocode_result = Geocoder.search(ip).first
    return false unless geocode_result

    %w[BY RU].include?(geocode_result.country_code)
  end
end
