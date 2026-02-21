# typed: strict
# frozen_string_literal: true

module Mcp
  module Tools
    class SearchAltsTool < BaseTool
      extend T::Sig

      sig { override.returns(String) }
      def self.tool_name
        "search_alts"
      end

      sig { override.returns(String) }
      def self.description
        "Search for alternate accounts by IP address or Steam ID. " \
        "Accepts multiple Steam IDs (comma-separated or array) for batch searches. " \
        "Can cross-reference to find all accounts that share IPs with given Steam IDs, " \
        "or all Steam IDs that have used a given IP address."
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def self.input_schema
        {
          type: "object",
          properties: {
            steam_uid: {
              oneOf: [
                { type: "string" },
                { type: "array", items: { type: "string" } }
              ],
              description: "Steam ID64(s) to search for. Accepts a single ID, comma-separated IDs, " \
                          "or an array of IDs. Also accepts Steam ID format (STEAM_0:0:123) or Steam ID3 ([U:1:123])."
            },
            ip: {
              type: "string",
              description: "IP address to search for (e.g., 192.168.1.100)"
            },
            cross_reference: {
              type: "boolean",
              description: "When true, finds all accounts sharing IPs with the given Steam ID, " \
                          "or all Steam IDs that have used the given IP. Default: true",
              default: true
            },
            reservation_ids: {
              type: "string",
              description: "Optional comma-separated list of reservation IDs to limit search scope"
            },
            include_vpn_results: {
              type: "boolean",
              description: "When true, includes VPN/hosting provider IPs in cross-reference results instead of filtering them out. " \
                          "Useful for investigating alt networks that use VPNs, but increases false positives. Default: true",
              default: true
            },
            first_seen_after: {
              type: "string",
              description: "Only include accounts first seen after this date (ISO 8601, e.g. 2025-01-01). Useful for finding newly created alts."
            }
          }
        }
      end

      sig { override.returns(Symbol) }
      def self.required_role
        :league_admin
      end

      sig { override.params(params: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def execute(params)
        steam_uid = normalize_steam_uids(params[:steam_uid])
        ip = params[:ip]&.to_s&.presence
        cross_reference = params.fetch(:cross_reference, true)
        include_vpn_results = params.fetch(:include_vpn_results, true)
        reservation_ids = params[:reservation_ids]&.to_s&.presence

        if steam_uid.blank? && ip.blank?
          return {
            accounts: [],
            target: nil,
            error: "At least one parameter (steam_uid or ip) is required"
          }
        end

        league_request = LeagueRequest.new(
          user,
          steam_uid: steam_uid,
          ip: ip,
          cross_reference: cross_reference ? "1" : nil,
          include_vpn_results: include_vpn_results,
          reservation_ids: reservation_ids
        )

        first_seen_after = params[:first_seen_after]&.to_s&.presence

        results = league_request.search
        asns = LeagueRequest.lookup_asns(results)
        banned_asns = LeagueRequest.precompute_banned_asns(asns)
        stac_detections = league_request.stac_detections(results)

        formatted_results = format_results(results, first_seen_after: first_seen_after)

        {
          target: league_request.target,
          accounts: formatted_results,
          asn_info: format_asns(asns, banned_asns),
          stac_detections: format_stac_detections(stac_detections),
          account_count: formatted_results.size
        }
      end

      private

      sig { params(input: T.untyped).returns(T.nilable(String)) }
      def normalize_steam_uids(input)
        return nil if input.blank?

        if input.is_a?(Array)
          input.map(&:to_s).reject(&:blank?).join(",").presence
        else
          input.to_s.presence
        end
      end

      sig { params(results: ActiveRecord::Relation, first_seen_after: T.nilable(String)).returns(T::Array[T::Hash[Symbol, T.untyped]]) }
      def format_results(results, first_seen_after: nil)
        aggregated = results.except(:select, :order)
          .select(
            "reservation_players.steam_uid",
            "MAX(reservation_players.name) AS latest_name",
            "MAX(reservation_players.ip) AS latest_ip",
            "MAX(reservation_players.asn_number) AS asn_number",
            "MAX(reservation_players.asn_organization) AS asn_organization",
            "COUNT(DISTINCT reservation_players.reservation_id) AS reservation_count",
            "MIN(reservations.starts_at) AS first_seen",
            "MAX(reservations.starts_at) AS last_seen"
          )
          .group("reservation_players.steam_uid")
          .order("last_seen DESC")

        if first_seen_after.present?
          aggregated = aggregated.having("MIN(reservations.starts_at) > ?", Time.zone.parse(first_seen_after))
        end

        banned_uids = ReservationPlayer.banned_uids

        steam_uids = aggregated.map(&:steam_uid)
        all_names = fetch_all_names(results, steam_uids)
        all_ips = fetch_all_ips(results, steam_uids)

        aggregated.map do |account|
          {
            steam_uid: account.steam_uid,
            name: account.latest_name,
            ip: account.latest_ip,
            asn_number: account.asn_number,
            asn_organization: account.asn_organization,
            reservation_count: account.reservation_count,
            first_seen: account.first_seen,
            last_seen: account.last_seen,
            all_names: all_names[account.steam_uid] || [],
            all_ips: all_ips[account.steam_uid] || [],
            banned: banned_uids.key?(account.steam_uid.to_i),
            ban_reason: banned_uids[account.steam_uid.to_i]
          }
        end
      end

      sig { params(results: ActiveRecord::Relation, steam_uids: T::Array[String]).returns(T::Hash[String, T::Array[String]]) }
      def fetch_all_names(results, steam_uids)
        return {} if steam_uids.empty?

        records = results.except(:select, :order)
          .where(steam_uid: steam_uids)
          .select("reservation_players.steam_uid, reservation_players.name")
          .distinct

        by_uid = Hash.new { |h, k| h[k] = [] }
        records.each { |r| by_uid[r.steam_uid] << r.name if r.name.present? }
        by_uid.transform_values(&:uniq)
      end

      sig { params(results: ActiveRecord::Relation, steam_uids: T::Array[String]).returns(T::Hash[String, T::Array[String]]) }
      def fetch_all_ips(results, steam_uids)
        return {} if steam_uids.empty?

        records = results.except(:select, :order)
          .where(steam_uid: steam_uids)
          .select("reservation_players.steam_uid, reservation_players.ip")
          .distinct

        by_uid = Hash.new { |h, k| h[k] = [] }
        records.each { |r| by_uid[r.steam_uid] << r.ip if r.ip.present? }
        by_uid.transform_values(&:uniq)
      end

      sig { params(asns: T::Hash[T.untyped, T.untyped], banned_asns: T::Hash[T.untyped, T.untyped]).returns(T::Hash[String, T::Hash[Symbol, T.untyped]]) }
      def format_asns(asns, banned_asns)
        asns.transform_values do |asn|
          next nil unless asn

          asn_number = asn.respond_to?(:autonomous_system_number) ? asn.autonomous_system_number : asn.asn_number
          {
            number: asn_number,
            organization: asn.respond_to?(:autonomous_system_organization) ? asn.autonomous_system_organization : asn.asn_organization,
            banned: banned_asns[asn_number] || false
          }
        end.compact
      end

      sig { params(detections: T::Array[T::Hash[Symbol, T.untyped]]).returns(T::Array[T::Hash[Symbol, T.untyped]]) }
      def format_stac_detections(detections)
        detections.map do |detection|
          {
            reservation_id: detection[:reservation_id],
            steam_uid: detection[:steam_uid],
            player_name: detection[:player_name],
            steam_id: detection[:steam_id],
            detections: detection[:detections],
            stac_log_filename: detection[:stac_log_filename]
          }
        end
      end
    end
  end
end
