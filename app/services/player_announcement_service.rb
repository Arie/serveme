# typed: false
# frozen_string_literal: true

class PlayerAnnouncementService
  def self.build_info(steam_uid, ip, reserver: true)
    location_parts = build_location_parts(steam_uid, ip, reserver: reserver)
    history_parts = build_history_parts(steam_uid)
    league_parts = build_league_parts(steam_uid)
    alt_parts = build_alt_parts(steam_uid)

    (location_parts + history_parts + league_parts + alt_parts).join(". ")
  end

  def self.build_location_parts(steam_uid, ip, reserver: true)
    if ReservationPlayer.sdr_ip?(ip)
      return [ "SDR" ]
    end

    parts = []

    geocode_result = Geocoder.search(ip).first
    if geocode_result
      if reserver
        location = [ geocode_result.state, geocode_result.country ].compact.reject(&:blank?).uniq.join(", ")
        parts << location if location.present?
      else
        parts << geocode_result.country if geocode_result.country.present?
      end
    end

    if reserver
      isp = find_asn_organization(steam_uid, ip)
      parts << isp if isp
    end

    parts
  end

  def self.find_asn_organization(steam_uid, ip)
    rp = ReservationPlayer.where(steam_uid: steam_uid, ip: ip).where.not(asn_organization: nil).order(id: :desc).first
    return rp.asn_organization if rp

    asn_data = ReservationPlayer.asn(ip)
    asn_data&.autonomous_system_organization
  end

  def self.build_history_parts(steam_uid)
    parts = []

    first_seen = ReservationPlayer
      .joins(:reservation)
      .where(steam_uid: steam_uid)
      .minimum("reservations.starts_at")

    parts << (first_seen ? "First seen: #{first_seen.strftime('%B %Y')}" : "First game")

    game_count = ReservationPlayer
      .joins(:reservation)
      .where(steam_uid: steam_uid)
      .distinct
      .count(:reservation_id)

    parts << "Games: #{game_count}" if game_count > 0

    vpn_attempt_count = ReservationPlayer
      .joins(:reservation)
      .where(steam_uid: steam_uid)
      .where(asn_number: ReservationPlayer.banned_asns)
      .where("reservations.starts_at >= ?", 30.days.ago)
      .without_sdr_ip
      .count

    parts << "VPN attempts: #{vpn_attempt_count}" if vpn_attempt_count > 0

    parts
  end

  def self.build_league_parts(steam_uid)
    parts = []

    if SITE_HOST == "serveme.tf"
      profile = Etf2lProfile.fetch(steam_uid)
      if profile
        div = profile.highest_division
        parts << "ETF2L: #{div}" if div
        parts << "ETF2L ban: #{profile.ban_reason}" if profile.banned?
      end
    elsif SITE_HOST == "na.serveme.tf"
      profile = RglProfile.fetch(steam_uid)
      if profile
        parts << "RGL ban: #{profile.ban_reason}" if profile.banned?
      end
    elsif SITE_HOST == "au.serveme.tf"
      profile = OzfortressProfile.fetch(steam_uid)
      if profile
        div = profile.highest_division
        parts << "ozfortress: #{div}" if div
      end
    end

    parts
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed
    []
  end

  def self.build_alt_parts(steam_uid)
    parts = []

    ips = ReservationPlayer
      .joins(reservation: :server)
      .where(steam_uid: steam_uid)
      .where(servers: { sdr: false })
      .without_sdr_ip
      .where("reservations.starts_at >= ?", 6.months.ago)
      .where.not(ip: nil)
      .where("asn_number IS NULL OR asn_number NOT IN (?)", ReservationPlayer.banned_asns)
      .distinct
      .pluck(:ip)

    if ips.any?
      alts = ReservationPlayer
        .joins(reservation: :server)
        .where(ip: ips)
        .where(servers: { sdr: false })
        .without_sdr_ip
        .where.not(steam_uid: steam_uid)
        .where("reservations.starts_at >= ?", 6.months.ago)
        .group(:steam_uid)
        .order(Arel.sql("MAX(reservations.starts_at) DESC"))
        .limit(5)
        .pluck(:steam_uid, Arel.sql("MAX(reservation_players.name)"))

      parts << "Possible alts: #{alts.map { |uid, name| "#{name} (#{uid})" }.join(', ')}" if alts.any?
    end

    parts
  end

  private_class_method :build_location_parts, :find_asn_organization, :build_history_parts, :build_league_parts, :build_alt_parts
end
