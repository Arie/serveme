# typed: true
# frozen_string_literal: true

class LeagueRequest
  extend T::Sig

  include ActiveModel::Model
  validates :ip, format: { with: /\A(?:[0-9]{1,3}\.){3}[0-9]{1,3}\Z/ }
  validates :steam_uid, format: { with: /\A765[0-9]{14}\Z/ }

  attr_accessor :ip, :steam_uid, :reservation_ids, :cross_reference, :include_vpn_results, :user, :target

  sig { params(user: User, ip: T.nilable(String), steam_uid: T.nilable(String), reservation_ids: T.nilable(T.any(String, T::Array[Integer])), cross_reference: T.nilable(String), include_vpn_results: T.nilable(T.any(String, T::Boolean))).void }
  def initialize(user, ip: nil, steam_uid: nil, reservation_ids: nil, cross_reference: nil, include_vpn_results: nil)
    @user = user
    @ip = parse_ips(ip)
    @steam_uid = parse_steam_uids(steam_uid)
    @reservation_ids =
      if reservation_ids.is_a?(String)
        reservation_ids.presence && reservation_ids.to_s.split(",").map(&:to_i)
      else
        reservation_ids
      end
    @cross_reference = (cross_reference == "1")
    @include_vpn_results = (include_vpn_results == "1" || include_vpn_results == true)
  end

  sig { returns(ActiveRecord::Relation) }
  def search
    @target = [ @ip, @steam_uid, @reservation_ids ].reject(&:blank?).join(", ")
    if @cross_reference
      Rails.logger.info("Cross reference search started by #{@user.name} (#{@user.uid}) for #{@target}")
      find_with_cross_reference(ip: @ip, steam_uid: @steam_uid)
    elsif @ip.present?
      Rails.logger.info("IP search started by #{@user.name} (#{@user.uid}) for #{@target}")
      find_by_ip(@ip)
    elsif @steam_uid.present?
      Rails.logger.info("Steam ID search started by #{@user.name} (#{@user.uid}) for #{@target}")
      find_by_steam_uid(@steam_uid)
    else
      Rails.logger.info("Reservation search started by #{@user.name} (#{@user.uid}) for #{@target}")
      find_by_reservation_ids(@reservation_ids)
    end
  end

  sig { params(search_results: T.nilable(ActiveRecord::Relation)).returns(T::Array[T::Hash[Symbol, T.untyped]]) }
  def stac_detections(search_results = nil)
    return [] unless search_results || @steam_uid.present?

    if search_results
      steam_uids = search_results.reorder("").distinct.pluck(:steam_uid).compact
      return [] if steam_uids.empty?
      find_stac_detections_for_steam_uids(steam_uids)
    else
      find_stac_detections_for_steam_uids(@steam_uid)
    end
  end

  sig { params(ip: T.any(String, T::Array[String])).returns(ActiveRecord::Relation) }
  def find_by_ip(ip)
    maybe_filter_by_reservation_ids(players_query.where(ip: ip))
  end

  sig { params(steam_uid: T.nilable(T.any(String, T::Array[String]))).returns(ActiveRecord::Relation) }
  def find_by_steam_uid(steam_uid)
    maybe_filter_by_reservation_ids(players_query.where(steam_uid: steam_uid))
  end

  sig { params(reservation_ids: T::Array[Integer]).returns(ActiveRecord::Relation) }
  def find_by_reservation_ids(reservation_ids)
    players_query.where(reservation_id: reservation_ids)
  end

  sig { params(ip: T.nilable(T.any(String, T::Array[String])), steam_uid: T.nilable(T.any(String, T::Array[String]))).returns(ActiveRecord::Relation) }
  def find_with_cross_reference(ip: nil, steam_uid: nil)
    if ip.present? && steam_uid.present?
      find_by_steam_uid_subquery(T.must(steam_uid)).or(find_by_ip_subquery(T.must(ip)))
    elsif ip.present?
      find_by_steam_uid_subquery(T.must(ip), :ip)
    else
      find_by_ip_subquery(T.must(steam_uid), :steam_uid)
    end
  end

  sig { params(results: ActiveRecord::Relation).returns(Hash) }
  def self.lookup_asns(results)
    asns = {}

    results.reorder("").distinct.pluck(:ip).each do |ip|
      asn = begin
        ReservationPlayer.asn(ip) if ip.present?
      rescue MaxMind::GeoIP2::AddressNotFoundError
        nil
      end
      asns[ip] = asn
    end

    asns
  end

  sig { params(asns: Hash).returns(Hash) }
  def self.precompute_banned_asns(asns)
    banned_asns = {}
    asns.each do |_ip, asn|
      next unless asn
      asn_number = asn.respond_to?(:autonomous_system_number) ? asn.autonomous_system_number : asn.asn_number
      banned_asns[asn_number] ||= ReservationPlayer.banned_asn?(asn) if asn_number
    end
    banned_asns
  end

  private

  sig { params(search_value: T.any(String, T::Array[String]), search_field: Symbol).returns(ActiveRecord::Relation) }
  def find_by_steam_uid_subquery(search_value, search_field = :steam_uid)
    subquery = base_players_query
      .where(search_field => search_value)
      .select(:steam_uid)
      .distinct

    if @reservation_ids.present?
      subquery = subquery.where(reservation_id: @reservation_ids)
    end

    if @cross_reference && search_field == :ip && !@include_vpn_results
      banned_asns = ReservationPlayer.banned_asns
      subquery = subquery.where("asn_number IS NULL OR asn_number NOT IN (?)", banned_asns)
    end

    apply_display_columns(maybe_filter_by_reservation_ids(base_players_query.where(steam_uid: subquery)))
  end

  sig { params(search_value: T.any(String, T::Array[String]), search_field: Symbol).returns(ActiveRecord::Relation) }
  def find_by_ip_subquery(search_value, search_field = :steam_uid)
    subquery = base_players_query
      .where(search_field => search_value)
      .select(:ip)
      .distinct

    if @reservation_ids.present?
      subquery = subquery.where(reservation_id: @reservation_ids)
    end

    if @cross_reference && !@include_vpn_results
      banned_asns = ReservationPlayer.banned_asns
      subquery = subquery.where("asn_number IS NULL OR asn_number NOT IN (?)", banned_asns)
    end

    apply_display_columns(maybe_filter_by_reservation_ids(base_players_query.where(ip: subquery)))
  end

  def maybe_filter_by_reservation_ids(query)
    if @reservation_ids
      query.where(reservation_id: @reservation_ids)
    else
      query
    end
  end

  sig { params(query: ActiveRecord::Relation).returns(ActiveRecord::Relation) }
  def apply_display_columns(query)
    query
      .select(
        "reservation_players.id",
        "reservation_players.reservation_id",
        "reservation_players.ip",
        "reservation_players.asn_number",
        "reservation_players.asn_organization",
        "reservation_players.asn_network",
        "reservation_players.name",
        "reservation_players.steam_uid",
        "reservations.starts_at AS reservation_starts_at",
        "reservations.ends_at AS reservation_ends_at"
      )
      .order("reservations.starts_at DESC")
  end

  sig { returns(ActiveRecord::Relation) }
  def base_players_query
    ReservationPlayer
      .joins(reservation: :server)
      .where(servers: { sdr: false })
      .without_sdr_ip
  end

  def players_query
    apply_display_columns(base_players_query)
  end

  def parse_ips(input)
    return nil unless input.present?

    ips = input.scan(/\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b/).uniq
    ips.empty? ? input.gsub(/[[:space:]]/, "").split(",").presence : ips
  end

  def parse_steam_uids(input)
    return nil unless input.present?

    converted_ids = []

    converted_ids.concat(input.scan(/\b765[0-9]{14}\b/).uniq)

    input.scan(/\[?U:1:\d+\]?/i).uniq.each do |steam_id|
      normalized_id = "[#{steam_id.gsub(/[\[\]]/, '').upcase}]"
      converted_ids << convert_to_steam64(normalized_id)
    end

    input.scan(/\bSTEAM_[0-5]:[01]:\d+\b/i).uniq.each do |steam_id|
      converted_ids << convert_to_steam64(steam_id.upcase)
    end

    converted_ids.compact!
    converted_ids.empty? ? input.gsub(/[[:space:]]/, "").split(",").presence : converted_ids.uniq
  end

  def convert_to_steam64(steam_id)
    SteamCondenser::Community::SteamId.steam_id_to_community_id(steam_id).to_s
  rescue StandardError
    nil
  end

  public

  sig { params(steam_uids: T.nilable(T.any(String, T::Array[String]))).returns(T::Array[T::Hash[Symbol, T.untyped]]) }
  def find_stac_detections_for_steam_uids(steam_uids)
    return [] unless steam_uids.present?

    steam_uids_array = Array(steam_uids).map(&:to_i)

    scope = StacDetection.where(steam_uid: steam_uids_array)
                         .includes(reservation: :server)
                         .includes(:stac_log)
    scope = scope.where(reservation_id: @reservation_ids) if @reservation_ids

    grouped = scope.group_by { |d| [ d.reservation_id, d.steam_uid ] }

    all_detections = []

    grouped.each do |(reservation_id, steam_uid), detections|
      first = T.must(detections.first)

      filtered = detections.reject do |d|
        d.detection_type.match?(StacDetection::FILTERED_TYPES) &&
          d.count < StacDetection::MIN_COUNT_THRESHOLD
      end
      next if filtered.empty?

      summarized = filtered.map do |d|
        d.count > 1 ? "#{d.detection_type} (#{d.count}x)" : d.detection_type
      end

      all_detections << {
        reservation_id: reservation_id,
        reservation: first.reservation,
        steam_uid: steam_uid.to_s,
        player_name: first.player_name,
        steam_id: first.steam_id,
        detections: summarized,
        stac_log_filename: first.stac_log&.filename
      }
    end

    all_detections.sort_by { |d| -d[:reservation_id] }
  end
end
