# typed: true
# frozen_string_literal: true

class ReservationPlayer < ActiveRecord::Base
  extend T::Sig

  require "csv"
  require "ipaddr"
  belongs_to :reservation, optional: true
  has_one :server, through: :reservation, autosave: false
  belongs_to :user, primary_key: :uid, foreign_key: :steam_uid, optional: true

  geocoded_by :ip
  before_save :geocode, if: :ip_changed?
  before_save :store_asn_data, if: :ip_changed?

  sig { returns(T.any(ActiveRecord::Relation, ActiveRecord::Associations::CollectionProxy)) }
  def duplicates
    self.class.where(reservation_id: reservation_id).where(steam_uid: steam_uid).where(ip: ip)
  end

  sig { returns(T.any(ActiveRecord::Relation, ActiveRecord::Associations::CollectionProxy)) }
  def self.whitelisted
    where(whitelisted: true)
  end

  sig { params(steam_profile: SteamCondenser::Community::SteamId).returns(T.nilable(T.any(T::Boolean, String))) }
  def self.banned?(steam_profile)
    (banned_name?(steam_profile.nickname) || banned_uid?(steam_profile.steam_id64)) && !whitelisted_uid?(steam_profile.steam_id64)
  end

  sig { params(nickname: String).returns(T::Boolean) }
  def self.banned_name?(nickname)
    nickname.include?("﷽")
  end

  sig { params(steam_id64: T.nilable(T.any(Integer, String))).returns(T.nilable(T.any(String, T::Boolean))) }
  def self.whitelisted_uid?(steam_id64)
    return true unless steam_id64

    whitelisted_uids[steam_id64.to_i]
  end

  sig { returns(T::Hash[Integer, String]) }
  def self.whitelisted_uids
    @whitelisted_uids ||= CSV.read(Rails.root.join("doc", "whitelisted_steam_ids.csv"), headers: true).to_h { |row| [ row["steam_id64"].to_i, row["reason"] ] }
  end

  sig { params(steam_id64: T.nilable(T.any(Integer, String))).returns(T.nilable(String)) }
  def self.banned_uid?(steam_id64)
    banned_uids[steam_id64.to_i]
  end

  sig { params(ip: T.nilable(String)).returns(T.nilable(T.any(String, T::Boolean))) }
  def self.banned_ip?(ip)
    return false unless ip

    banned_ip = banned_ips.find { |range, _reason| range.include?(ip) }

    banned_ip && banned_ip[1]
  end

  sig { params(steam_id64: T.any(Integer, String)).returns(T.nilable(T::Boolean)) }
  def self.banned_league_uid?(steam_id64)
    LeagueBan.fetch(steam_id64)&.banned?
  end

  sig { returns(T::Hash[Integer, String]) }
  def self.banned_uids
    @banned_uids ||= CSV.read(Rails.root.join("doc", "banned_steam_ids.csv"), headers: true).to_h { |row| [ row["steam_id64"].to_i, row["reason"] ] }
  end

  sig { returns(T::Array[String]) }
  def self.banned_ips
    @banned_ips ||= CSV.read(Rails.root.join("doc", "banned_ips.csv"), headers: true).map { |row| [ IPAddr.new(row["ip"]), row["reason"] ] }
  end

  sig { returns(T::Array[String]) }
  def self.vpn_ranges
    @vpn_ranges ||= CSV.read(Rails.root.join("doc", "vpn_ips.csv"), headers: true).map { |row| IPAddr.new(row["ip"]) }
  end

  sig { params(ip: T.nilable(String)).returns(T.nilable(T::Boolean)) }
  def self.banned_asn_ip?(ip)
    banned_asn?(asn(ip)) || (ip && vpn_ranges.any? { |range| range.include?(ip) })
  end

  sig { params(asn: T.nilable(MaxMind::GeoIP2::Model::ASN)).returns(T::Boolean) }
  def self.banned_asn?(asn)
    !!asn && (banned_asns.include?(asn.autonomous_system_number) || custom_banned_asns.include?(asn.autonomous_system_number))
  end

  sig { params(ip: T.nilable(String)).returns(T.nilable(MaxMind::GeoIP2::Model::ASN)) }
  def self.asn(ip)
    return nil if IPAddr.new("169.254.0.0/16").include?(ip)

    begin
      $maxmind_asn.asn(ip)
    rescue MaxMind::GeoIP2::AddressNotFoundError
      nil
    end
  end

  sig { returns(T::Array[Integer]) }
  def self.banned_asns
    @banned_asns ||= CSV.read(Rails.root.join("doc", "bad-asn-list.csv"), headers: true).map { |row| row["ASN"].to_i }
  end

  sig { returns(T::Array[Integer]) }
  def self.custom_banned_asns
    [
      3214, # xTom
      5631, # Luminet Data Limited
      7195, # EdgeUno
      46844, # Sharktech.net
      59711, # HZ Hosting Ltd
      136787, # TEFINCOM S.A.
      212238, # Datacamp
      397423 # Tier.net
    ]
  end

  sig { params(ip: String).returns(T::Boolean) }
  def self.banned_country?(ip)
    geocode_result = Geocoder.search(ip).first
    return false unless geocode_result

    %w[BY RU].include?(geocode_result.country_code)
  end

  sig { returns(T.nilable(MaxMind::GeoIP2::Model::ASN)) }
  def asn
    @asn ||= self.class.asn(ip)
  end

  private

  sig { void }
  def store_asn_data
    return unless ip.present?

    asn_data = self.class.asn(ip)
    if asn_data
      self.asn_number = asn_data.autonomous_system_number
      self.asn_organization = asn_data.autonomous_system_organization
      self.asn_network = asn_data.network.to_s
    else
      self.asn_number = nil
      self.asn_organization = nil
      self.asn_network = nil
    end
  end
end
