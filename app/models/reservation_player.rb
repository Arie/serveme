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

  SDR_IP_PREFIX = "169.254."
  SDR_IP_RANGE_CIDR = "169.254.0.0/16"
  SDR_IP_SQL_PATTERN = "169.254.%"

  scope :with_sdr_ip, -> { where("reservation_players.ip LIKE ?", SDR_IP_SQL_PATTERN) }
  scope :without_sdr_ip, -> { where.not("reservation_players.ip LIKE ?", SDR_IP_SQL_PATTERN) }

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
    return banned_ip[1] if banned_ip

    IpLookup.where(ip: ip, is_banned: true).pick(:ban_reason)
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
    !!asn && banned_asns.include?(asn.autonomous_system_number)
  end

  sig { params(ip: T.nilable(String)).returns(T.nilable(MaxMind::GeoIP2::Model::ASN)) }
  def self.asn(ip)
    return nil if ip && sdr_ip_range?(ip)

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

  sig { params(ip: String).returns(T::Boolean) }
  def self.sdr_ip?(ip)
    ip.start_with?(SDR_IP_PREFIX)
  end

  sig { params(ip: String).returns(T::Boolean) }
  def self.sdr_ip_range?(ip)
    sdr_ip_range.include?(ip)
  end

  sig { returns(IPAddr) }
  def self.sdr_ip_range
    @sdr_ip_range ||= IPAddr.new(SDR_IP_RANGE_CIDR)
  end

  sig { params(steam_uid: Integer, reservation_id: Integer).returns(T::Boolean) }
  def self.has_connected_with_normal_ip?(steam_uid, reservation_id)
    ips = where(steam_uid: steam_uid, reservation_id: reservation_id)
      .where.not(ip: nil)
      .without_sdr_ip
      .pluck(:ip)
      .uniq

    ips.any? { |ip| !banned_ip?(ip) && !banned_asn_ip?(ip) }
  end

  sig { params(steam_uid: Integer).returns(T::Boolean) }
  def self.has_connected_with_normal_ip_recently?(steam_uid)
    ips = joins(:reservation)
      .where(steam_uid: steam_uid)
      .where("reservations.starts_at >= ?", 1.week.ago)
      .where.not(ip: nil)
      .without_sdr_ip
      .pluck(:ip)
      .uniq

    ips.any? { |ip| !banned_ip?(ip) && !banned_asn_ip?(ip) }
  end

  sig { params(steam_uid: Integer).returns(T::Boolean) }
  def self.has_logged_in_with_normal_ip_recently?(steam_uid)
    user = User.find_by(uid: steam_uid)
    return false unless user&.current_sign_in_ip

    updated_at = user.updated_at
    return false unless updated_at && updated_at >= 1.week.ago

    ip = user.current_sign_in_ip
    !banned_ip?(ip) && !banned_asn_ip?(ip)
  end

  sig { params(steam_uid: Integer).returns(T::Boolean) }
  def self.longtime_serveme_player?(steam_uid)
    oldest_reservation_starts_at = joins(:reservation)
      .where(steam_uid: steam_uid)
      .minimum("reservations.starts_at")

    return false unless oldest_reservation_starts_at

    oldest_reservation_starts_at < 1.year.ago
  end

  sig { params(steam_uid: Integer).returns(T::Boolean) }
  def self.sdr_eligible_steam_profile?(steam_uid)
    return true if longtime_serveme_player?(steam_uid)

    has_connected_with_normal_ip_recently?(steam_uid) || has_logged_in_with_normal_ip_recently?(steam_uid)
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
