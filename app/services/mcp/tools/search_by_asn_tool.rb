# typed: strict
# frozen_string_literal: true

module Mcp
  module Tools
    class SearchByAsnTool < BaseTool
      extend T::Sig

      sig { override.returns(String) }
      def self.tool_name
        "search_by_asn"
      end

      sig { override.returns(String) }
      def self.description
        "Search for all accounts that have connected from a specific ASN (Autonomous System Number). " \
        "Useful for finding alt accounts from the same ISP. " \
        "Returns unique Steam accounts grouped by their activity, with optional date filtering."
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def self.input_schema
        {
          type: "object",
          properties: {
            asn_number: {
              type: "integer",
              description: "ASN number to search for (e.g., 8708 for Digi Romania)"
            },
            days: {
              type: "integer",
              description: "Only search reservations from the last N days. Default: 90",
              default: 90
            },
            limit: {
              type: "integer",
              description: "Maximum number of unique accounts to return. Default: 50",
              default: 50
            }
          },
          required: [ "asn_number" ]
        }
      end

      sig { override.returns(Symbol) }
      def self.required_role
        :league_admin
      end

      sig { override.params(params: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def execute(params)
        asn_number = params[:asn_number]&.to_i
        days = [ params.fetch(:days, 90).to_i, 365 ].min
        limit = [ params.fetch(:limit, 50).to_i, 200 ].min

        if asn_number.blank? || asn_number <= 0
          return {
            error: "Valid ASN number is required",
            accounts: [],
            asn_number: nil
          }
        end

        Rails.logger.info("ASN search started by #{user.name} (#{user.uid}) for ASN #{asn_number}")

        cutoff_date = days.days.ago

        # Find all unique steam accounts that have used this ASN
        accounts_query = base_players_query
          .where(asn_number: asn_number)
          .where("reservations.starts_at >= ?", cutoff_date)

        # Get unique accounts with their most recent activity
        unique_accounts = accounts_query
          .select(
            "reservation_players.steam_uid",
            "MAX(reservation_players.name) AS latest_name",
            "MAX(reservation_players.ip) AS latest_ip",
            "MAX(reservation_players.asn_organization) AS asn_organization",
            "COUNT(DISTINCT reservation_players.reservation_id) AS reservation_count",
            "MAX(reservations.starts_at) AS last_seen",
            "MIN(reservations.starts_at) AS first_seen"
          )
          .group("reservation_players.steam_uid")
          .order("last_seen DESC")
          .limit(limit)

        accounts = unique_accounts.map do |account|
          {
            steam_uid: account.steam_uid,
            name: account.latest_name,
            ip: account.latest_ip,
            reservation_count: account.reservation_count,
            first_seen: account.first_seen,
            last_seen: account.last_seen
          }
        end

        # Get all names used by each account
        steam_uids = accounts.map { |a| a[:steam_uid] }
        names_by_uid = fetch_all_names(steam_uids, asn_number, cutoff_date)

        accounts.each do |account|
          account[:all_names] = names_by_uid[account[:steam_uid]] || []
        end

        # Get STAC detections for these accounts
        stac_detections = find_stac_detections(steam_uids)

        # Get ASN organization name
        asn_org = accounts.first&.dig(:asn_organization) || lookup_asn_org(asn_number)

        {
          asn_number: asn_number,
          asn_organization: asn_org,
          search_period_days: days,
          accounts: accounts,
          account_count: accounts.size,
          stac_detections: stac_detections
        }
      end

      private

      sig { returns(ActiveRecord::Relation) }
      def base_players_query
        ReservationPlayer
          .joins(reservation: :server)
          .where(servers: { sdr: false })
          .without_sdr_ip
      end

      sig { params(steam_uids: T::Array[String], asn_number: Integer, cutoff_date: ActiveSupport::TimeWithZone).returns(T::Hash[String, T::Array[String]]) }
      def fetch_all_names(steam_uids, asn_number, cutoff_date)
        return {} if steam_uids.empty?

        names_records = base_players_query
          .where(steam_uid: steam_uids, asn_number: asn_number)
          .where("reservations.starts_at >= ?", cutoff_date)
          .select("reservation_players.steam_uid, reservation_players.name")
          .distinct

        names_by_uid = Hash.new { |h, k| h[k] = [] }
        names_records.each do |record|
          names_by_uid[record.steam_uid] << record.name if record.name.present?
        end
        names_by_uid.transform_values(&:uniq)
      end

      sig { params(steam_uids: T::Array[String]).returns(T::Array[T::Hash[Symbol, T.untyped]]) }
      def find_stac_detections(steam_uids)
        return [] if steam_uids.empty?

        league_request = LeagueRequest.new(user, steam_uid: steam_uids.join(","))
        detections = league_request.stac_detections

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

      sig { params(asn_number: Integer).returns(T.nilable(String)) }
      def lookup_asn_org(asn_number)
        # Try to find any record with this ASN to get the organization name
        record = ReservationPlayer.where(asn_number: asn_number).limit(1).pick(:asn_organization)
        record
      end
    end
  end
end
