# typed: true
# frozen_string_literal: true

class BanAppealUserInfoService
  extend T::Sig

  sig { params(admin_user: T.untyped, steam_uid: T.untyped, discord_uid: T.untyped).void }
  def initialize(admin_user:, steam_uid: nil, discord_uid: nil)
    @steam_uid = steam_uid
    @discord_uid = discord_uid
    @admin_user = admin_user
  end

  sig { returns(T::Hash[Symbol, T.untyped]) }
  def collect
    user = find_user
    steam_uid = user&.uid || @steam_uid

    reservation_players = ReservationPlayer.where(steam_uid: steam_uid)

    return { found: false } unless user || reservation_players.exists?

    nickname = reservation_players.order("reservation_id DESC").pick(:name) || user&.nickname || steam_uid
    reservation_count = user ? user.reservations.count : 0
    ban_reason = ReservationPlayer.banned_uid?(steam_uid) || nil
    banned = ban_reason.present?

    ips = reservation_players.where.not(ip: nil).distinct.pluck(:ip)
    games_played = reservation_players.select(:reservation_id).distinct.count

    first_seen = reservation_players.joins(:reservation).minimum("reservations.starts_at")
    last_seen = reservation_players.joins(:reservation).maximum("reservations.starts_at")

    {
      found: true,
      region: detect_region,
      steam_uid: steam_uid,
      nickname: nickname,
      discord_uid: user&.discord_uid,
      banned: banned,
      ban_reason: ban_reason,
      ban_type: detect_ban_type(ban_reason, ips),
      reservation_count: reservation_count,
      games_played: games_played,
      first_seen: first_seen&.iso8601,
      last_seen: last_seen&.iso8601,
      ips: ips,
      alts: find_alts(steam_uid),
      ip_lookups: ip_lookups(ips),
      stac_detections: stac_detections(steam_uid)
    }
  end

  private

  sig { returns(T.nilable(User)) }
  def find_user
    if @steam_uid.present?
      User.find_by(uid: @steam_uid)
    elsif @discord_uid.present?
      User.find_by(discord_uid: @discord_uid)
    end
  end

  sig { params(steam_uid: T.untyped).returns(T::Array[T::Hash[Symbol, T.untyped]]) }
  def find_alts(steam_uid)
    tool = Mcp::Tools::SearchAltsTool.new(@admin_user)
    result = tool.execute(steam_uid: steam_uid, cross_reference: true, include_vpn_results: true)
    (result[:accounts] || []).reject { |a| a[:steam_uid].to_s == steam_uid.to_s }.first(20).map do |account|
      {
        steam_uid: account[:steam_uid],
        name: account[:name],
        reservation_count: account[:reservation_count],
        banned: account[:banned],
        ban_reason: account[:ban_reason],
        region: detect_region
      }
    end
  rescue StandardError => e
    Rails.logger.warn "[BanAppealUserInfo] Alt search failed: #{e.message}"
    []
  end

  sig { params(steam_uid: T.untyped).returns(T::Array[T::Hash[Symbol, T.untyped]]) }
  def stac_detections(steam_uid)
    StacDetection.where(steam_uid: steam_uid).group(:detection_type).sum(:count).map do |type, count|
      { detection_type: type, count: count }
    end
  end

  sig { params(ban_reason: T.untyped, ips: T::Array[T.untyped]).returns(T::Array[String]) }
  def detect_ban_type(ban_reason, ips)
    types = []
    types << "UID" if ban_reason.present?
    ips.each do |ip|
      if ReservationPlayer.banned_ip?(ip)
        types << "IP"
        break
      end
    end
    types
  end

  sig { params(ips: T::Array[T.untyped]).returns(T::Array[T::Hash[Symbol, T.untyped]]) }
  def ip_lookups(ips)
    IpLookup.where(ip: ips).map do |lookup|
      {
        ip: lookup.ip,
        fraud_score: lookup.fraud_score,
        is_proxy: lookup.is_proxy,
        is_residential_proxy: lookup.is_residential_proxy,
        isp: lookup.isp,
        country_code: lookup.country_code,
        is_banned: lookup.is_banned,
        ban_reason: lookup.ban_reason
      }
    end
  end

  sig { returns(String) }
  def detect_region
    case SITE_HOST
    when "na.serveme.tf" then "na"
    when "sea.serveme.tf" then "sea"
    when "au.serveme.tf" then "au"
    else "eu"
    end
  end
end
