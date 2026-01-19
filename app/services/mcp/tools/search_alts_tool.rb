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
        "Can cross-reference to find all accounts that share IPs with a given Steam ID, " \
        "or all Steam IDs that have used a given IP address."
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def self.input_schema
        {
          type: "object",
          properties: {
            steam_uid: {
              type: "string",
              description: "Steam ID64 to search for (e.g., 76561198012345678). " \
                          "Also accepts Steam ID format (STEAM_0:0:123) or Steam ID3 ([U:1:123])."
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
        steam_uid = params[:steam_uid]&.to_s&.presence
        ip = params[:ip]&.to_s&.presence
        cross_reference = params.fetch(:cross_reference, true)
        reservation_ids = params[:reservation_ids]&.to_s&.presence

        if steam_uid.blank? && ip.blank?
          return {
            results: [],
            target: nil,
            error: "At least one parameter (steam_uid or ip) is required"
          }
        end

        league_request = LeagueRequest.new(
          user,
          steam_uid: steam_uid,
          ip: ip,
          cross_reference: cross_reference ? "1" : nil,
          reservation_ids: reservation_ids
        )

        results = league_request.search
        asns = LeagueRequest.lookup_asns(results)
        banned_asns = LeagueRequest.precompute_banned_asns(asns)
        stac_detections = league_request.stac_detections(results)

        formatted_results = format_results(results)

        {
          target: league_request.target,
          results: formatted_results,
          asn_info: format_asns(asns, banned_asns),
          stac_detections: format_stac_detections(stac_detections),
          result_count: formatted_results.size
        }
      end

      private

      sig { params(results: ActiveRecord::Relation).returns(T::Array[T::Hash[Symbol, T.untyped]]) }
      def format_results(results)
        results.map do |player|
          {
            reservation_id: player.reservation_id,
            steam_uid: player.steam_uid,
            name: player.name,
            ip: player.ip,
            asn_number: player.asn_number,
            asn_organization: player.asn_organization,
            reservation_starts_at: player.respond_to?(:reservation_starts_at) ? player.reservation_starts_at : nil,
            reservation_ends_at: player.respond_to?(:reservation_ends_at) ? player.reservation_ends_at : nil
          }
        end
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
