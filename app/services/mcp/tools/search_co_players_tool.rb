# typed: strict
# frozen_string_literal: true

module Mcp
  module Tools
    class SearchCoPlayersTool < BaseTool
      extend T::Sig

      sig { override.returns(String) }
      def self.tool_name
        "search_co_players"
      end

      sig { override.returns(String) }
      def self.description
        "Find players who frequently share reservations with a target player. " \
        "Useful for identifying teams, friends, or potential alt account networks."
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def self.input_schema
        {
          type: "object",
          properties: {
            steam_uid: {
              type: "string",
              description: "Steam ID64 of the target player to find co-players for"
            },
            min_shared: {
              type: "integer",
              description: "Minimum number of shared reservations to include a co-player. Min: 1, Default: 3",
              default: 3
            },
            days: {
              type: "integer",
              description: "Only search reservations from the last N days. Default: 365",
              default: 365
            },
            limit: {
              type: "integer",
              description: "Maximum number of co-players to return. Default: 25",
              default: 25
            }
          },
          required: [ "steam_uid" ]
        }
      end

      sig { override.returns(Symbol) }
      def self.required_role
        :league_admin
      end

      sig { override.params(params: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def execute(params)
        steam_uid = params[:steam_uid]&.to_s&.presence
        min_shared = [ params.fetch(:min_shared, 3).to_i, 1 ].max
        days = [ params.fetch(:days, 365).to_i, 730 ].min
        limit = [ params.fetch(:limit, 25).to_i, 100 ].min

        if steam_uid.blank?
          return {
            error: "steam_uid is required",
            co_players: [],
            steam_uid: nil
          }
        end

        Rails.logger.info("Co-player search started by #{user.name} (#{user.uid}) for #{steam_uid}")

        cutoff_date = days.days.ago

        # Find all reservation IDs the target player participated in
        target_reservation_ids = base_players_query
          .where(steam_uid: steam_uid)
          .where("reservations.starts_at >= ?", cutoff_date)
          .select(:reservation_id)
          .distinct

        target_reservation_count = target_reservation_ids.count

        # Find co-players: other players in those same reservations
        co_players_query = base_players_query
          .where(reservation_id: target_reservation_ids)
          .where.not(steam_uid: steam_uid)
          .where("reservations.starts_at >= ?", cutoff_date)
          .select(
            "reservation_players.steam_uid",
            "MAX(reservation_players.name) AS latest_name",
            "COUNT(DISTINCT reservation_players.reservation_id) AS shared_reservation_count",
            "MIN(reservations.starts_at) AS first_seen",
            "MAX(reservations.starts_at) AS last_seen"
          )
          .group("reservation_players.steam_uid")
          .having("COUNT(DISTINCT reservation_players.reservation_id) >= ?", min_shared)
          .order("shared_reservation_count DESC")
          .limit(limit)

        co_players = co_players_query.map do |player|
          {
            steam_uid: player.steam_uid,
            name: player.latest_name,
            shared_reservation_count: player.shared_reservation_count,
            first_seen: player.first_seen,
            last_seen: player.last_seen
          }
        end

        # Get all names used by each co-player
        steam_uids = co_players.map { |p| p[:steam_uid] }
        names_by_uid = fetch_all_names(steam_uids, target_reservation_ids, cutoff_date)

        co_players.each do |player|
          player[:all_names] = names_by_uid[player[:steam_uid]] || []
        end

        # Get STAC detections for these accounts
        stac_detections = find_stac_detections(steam_uids)

        {
          steam_uid: steam_uid,
          target_reservation_count: target_reservation_count,
          search_period_days: days,
          min_shared: min_shared,
          co_players: co_players,
          co_player_count: co_players.size,
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

      sig { params(steam_uids: T::Array[String], target_reservation_ids: T.untyped, cutoff_date: ActiveSupport::TimeWithZone).returns(T::Hash[String, T::Array[String]]) }
      def fetch_all_names(steam_uids, target_reservation_ids, cutoff_date)
        return {} if steam_uids.empty?

        names_records = base_players_query
          .where(steam_uid: steam_uids)
          .where(reservation_id: target_reservation_ids)
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
    end
  end
end
