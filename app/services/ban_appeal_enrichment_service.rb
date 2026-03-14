# typed: false
# frozen_string_literal: true

class BanAppealEnrichmentService
  REGIONS = {
    na: "https://direct.na.serveme.tf",
    sea: "https://direct.sea.serveme.tf",
    au: "https://direct.au.serveme.tf"
  }.freeze

  def initialize(discord_uid)
    @discord_uid = discord_uid
  end

  def collect
    # Step 1: Check EU locally
    local_data = collect_local_data

    # Step 2: Query other regions
    remote_data = collect_remote_data(local_data&.dig(:steam_uid))

    # Step 3: Merge all results
    all_data = [ local_data, *remote_data ].compact.select { |d| d[:found] }

    return { found: false } if all_data.empty?

    merge_results(all_data)
  end

  private

  def collect_local_data
    user = User.find_by(discord_uid: @discord_uid)
    steam_uid = user&.uid
    return nil unless steam_uid

    reservation_players = ReservationPlayer.where(steam_uid: steam_uid)
    ips = reservation_players.where.not(ip: nil).distinct.pluck(:ip)
    games_played = reservation_players.select(:reservation_id).distinct.count

    # Prefer in-game name from most recent reservation, fall back to Steam profile name
    nickname = reservation_players.order("reservation_id DESC").pick(:name) || user&.nickname || steam_uid
    reservation_count = user ? user.reservations.count : 0
    ban_reason = ReservationPlayer.banned_uid?(steam_uid) || nil
    banned = ban_reason.present?

    first_seen = reservation_players.joins(:reservation).minimum("reservations.starts_at")
    last_seen = reservation_players.joins(:reservation).maximum("reservations.starts_at")

    alts = find_local_alts(steam_uid, ips)
    ip_lookups = IpLookup.where(ip: ips).map { |l| ip_lookup_hash(l) }
    stac_detections = find_local_stac_detections(steam_uid)
    ban_type = detect_ban_type(steam_uid, ips)

    {
      found: true,
      region: "eu",
      steam_uid: steam_uid,
      nickname: nickname,
      discord_uid: user&.discord_uid,
      banned: banned,
      ban_reason: ban_reason,
      ban_type: ban_type,
      reservation_count: reservation_count,
      games_played: games_played,
      first_seen: first_seen&.iso8601,
      last_seen: last_seen&.iso8601,
      ips: ips,
      alts: alts,
      ip_lookups: ip_lookups,
      stac_detections: stac_detections
    }
  end

  def collect_remote_data(steam_uid)
    results = []

    REGIONS.each do |region_key, base_url|
      api_key = Rails.application.credentials.dig(:serveme, region_key)
      next unless api_key

      data = fetch_remote_region(region_key, base_url, api_key, steam_uid)
      results << data if data
    end

    results
  end

  def fetch_remote_region(region_key, base_url, api_key, steam_uid)
    conn = Faraday.new(url: base_url) do |f|
      f.response :json
      f.options.timeout = 10
      f.options.open_timeout = 5
    end

    query_params = if steam_uid
      { steam_uid: steam_uid }
    else
      { discord_uid: @discord_uid }
    end

    response = conn.get("/api/ban_appeals/user_info") do |req|
      req.headers["Authorization"] = "Bearer #{api_key}"
      req.params = query_params
    end

    return nil unless response.success?

    data = response.body
    return nil unless data

    data.deep_symbolize_keys
  rescue Faraday::Error => e
    Rails.logger.warn "[BanAppealEnrichment] Error fetching ban appeal data from #{region_key}: #{e.message}"
    nil
  end

  def merge_results(all_data)
    # Use data from region with most recent last_seen for nickname
    most_recent = all_data.max_by { |d| d[:last_seen] || "" }

    # Merge reservation counts and games played
    total_reservations = all_data.sum { |d| d[:reservation_count].to_i }
    total_games_played = all_data.sum { |d| d[:games_played].to_i }

    # Earliest first_seen, latest last_seen
    first_seen = all_data.map { |d| d[:first_seen] }.compact.min
    last_seen = all_data.map { |d| d[:last_seen] }.compact.max

    # Union IPs
    all_ips = all_data.flat_map { |d| d[:ips] || [] }.uniq

    # Union alts by steam_uid
    all_alts = merge_alts(all_data)

    # Union IP lookups by IP (deduplicate)
    all_ip_lookups = all_data.flat_map { |d| d[:ip_lookups] || [] }
      .uniq { |l| l[:ip] }

    # Ban status (same across regions since CSV is global)
    banned = all_data.any? { |d| d[:banned] }
    ban_reason = all_data.find { |d| d[:ban_reason] }&.dig(:ban_reason)

    # Ban types from all regions
    ban_types = all_data.flat_map { |d| d[:ban_type] || [] }.uniq

    # Union STAC detections
    all_stac = all_data.flat_map { |d| d[:stac_detections] || [] }

    # Regions with data
    regions = all_data.map { |d| d[:region] }.compact

    {
      found: true,
      steam_uid: most_recent[:steam_uid],
      nickname: most_recent[:nickname],
      discord_uid: @discord_uid,
      banned: banned,
      ban_reason: ban_reason,
      ban_type: ban_types,
      reservation_count: total_reservations,
      games_played: total_games_played,
      first_seen: first_seen,
      last_seen: last_seen,
      regions: regions,
      ips: all_ips,
      alts: all_alts,
      ip_lookups: all_ip_lookups,
      stac_detections: all_stac
    }
  end

  def merge_alts(all_data)
    by_uid = {}

    all_data.each do |data|
      (data[:alts] || []).each do |alt|
        uid = alt[:steam_uid]
        existing = by_uid[uid]
        if existing
          existing[:reservation_count] = [ existing[:reservation_count].to_i, alt[:reservation_count].to_i ].max
          existing[:banned] ||= alt[:banned]
          existing[:ban_reason] ||= alt[:ban_reason]
        else
          by_uid[uid] = alt.dup
        end
      end
    end

    by_uid.values
  end

  def find_local_alts(steam_uid, _ips)
    # Use a system user for the search (any admin would do, but we need a User object)
    admin = User.joins(:groups).where(groups: { id: Group.admin_group.id }).first
    return [] unless admin

    tool = Mcp::Tools::SearchAltsTool.new(admin)
    result = tool.execute(steam_uid: steam_uid, cross_reference: true, include_vpn_results: true)
    (result[:accounts] || []).reject { |a| a[:steam_uid].to_s == steam_uid.to_s }.first(20).map do |account|
      {
        steam_uid: account[:steam_uid],
        name: account[:name],
        reservation_count: account[:reservation_count],
        banned: account[:banned],
        ban_reason: account[:ban_reason],
        region: "eu"
      }
    end
  rescue StandardError => e
    Rails.logger.warn "[BanAppealEnrichment] Alt search failed: #{e.message}"
    []
  end

  def find_local_stac_detections(steam_uid)
    StacDetection.where(steam_uid: steam_uid).group(:detection_type).sum(:count).map do |type, count|
      { detection_type: type, count: count }
    end
  rescue StandardError => e
    Rails.logger.warn "[BanAppealEnrichment] STAC detection lookup failed: #{e.message}"
    []
  end

  def detect_ban_type(steam_uid, ips)
    types = []
    types << "UID" if ReservationPlayer.banned_uid?(steam_uid)
    ips.each do |ip|
      if ReservationPlayer.banned_ip?(ip)
        types << "IP"
        break
      end
    end
    types
  end

  def ip_lookup_hash(lookup)
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
