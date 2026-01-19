# typed: strict
# frozen_string_literal: true

module Mcp
  module Tools
    class ListReservationsTool < BaseTool
      extend T::Sig

      sig { override.returns(String) }
      def self.tool_name
        "list_reservations"
      end

      sig { override.returns(String) }
      def self.description
        "List and search reservations. Filter by status (current, future, past), " \
        "user, server, or date range. Returns reservation details including " \
        "server info, passwords, and RCON credentials."
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def self.input_schema
        {
          type: "object",
          properties: {
            status: {
              type: "string",
              enum: [ "current", "future", "past", "all" ],
              description: "Filter by reservation status. Default: all"
            },
            user_query: {
              type: "string",
              description: "Find user by Steam profile URL (steamcommunity.com/id/... or /profiles/...), " \
                          "Steam ID64, Steam ID, Steam ID3, user ID, or nickname"
            },
            user_id: {
              type: "integer",
              description: "Filter by user ID (use user_query for more flexible lookup)"
            },
            steam_uid: {
              type: "string",
              description: "Filter by Steam ID64 (use user_query for more flexible lookup)"
            },
            server_id: {
              type: "integer",
              description: "Filter by server ID"
            },
            limit: {
              type: "integer",
              description: "Maximum number of results. Default: 25",
              default: 25
            }
          }
        }
      end

      sig { override.returns(Symbol) }
      def self.required_role
        :admin
      end

      sig { override.params(params: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def execute(params)
        # Resolve user_query first if provided
        if params[:user_query].present?
          resolved_user = resolve_user(params[:user_query])
          return resolved_user if resolved_user[:error]

          params = params.merge(user_id: resolved_user[:user_id])
        end

        reservations = build_query(params)
        limit = [ params.fetch(:limit, 25).to_i, 100 ].min

        reservations = reservations.limit(limit)

        {
          reservations: reservations.map { |r| format_reservation(r) },
          total_count: reservations.size
        }
      end

      private

      sig { params(query: String).returns(T::Hash[Symbol, T.untyped]) }
      def resolve_user(query)
        results = UserSearchService.new(query.to_s.strip).search

        if results.empty?
          return { error: "User not found for query: #{query}", reservations: nil }
        end

        if results.size > 1
          # If multiple results, try to find an exact match by uid or return first
          exact_match = results.find { |u| u.uid == query.to_s.strip }
          user = exact_match || T.must(results.first)
        else
          user = T.must(results.first)
        end

        { user_id: user.id }
      end

      sig { params(params: T::Hash[Symbol, T.untyped]).returns(ActiveRecord::Relation) }
      def build_query(params)
        # Status filter - apply scopes first, then order
        # Using T.unsafe to bypass Sorbet's lack of knowledge about custom scopes
        reservations = case params[:status]&.to_s
        when "current"
          T.unsafe(Reservation).current.with_user_and_server.order(starts_at: :desc)
        when "future"
          T.unsafe(Reservation).future.with_user_and_server.order(starts_at: :desc)
        when "past"
          T.unsafe(Reservation).with_user_and_server.where(ends_at: ...Time.current).order(starts_at: :desc)
        else
          Reservation.ordered
        end

        # User filter
        if params[:user_id].present?
          reservations = reservations.where(user_id: params[:user_id])
        elsif params[:steam_uid].present?
          user = User.find_by(uid: params[:steam_uid])
          reservations = reservations.where(user_id: user&.id)
        end

        # Server filter
        if params[:server_id].present?
          reservations = reservations.where(server_id: params[:server_id])
        end

        reservations
      end

      sig { params(reservation: Reservation).returns(T::Hash[Symbol, T.untyped]) }
      def format_reservation(reservation)
        {
          id: reservation.id,
          user_id: reservation.user_id,
          user_nickname: reservation.user&.nickname,
          user_steam_uid: reservation.user&.uid,
          server_id: reservation.server_id,
          server_name: reservation.server&.name,
          starts_at: reservation.starts_at,
          ends_at: reservation.ends_at,
          password: reservation.password,
          rcon: reservation.rcon,
          tv_password: reservation.tv_password,
          status: reservation_status(reservation),
          first_map: reservation.first_map,
          server_config: reservation.server_config&.file,
          enable_plugins: reservation.enable_plugins?,
          enable_demos_tf: reservation.enable_demos_tf?
        }
      end

      sig { params(reservation: Reservation).returns(String) }
      def reservation_status(reservation)
        if reservation.now?
          "current"
        elsif reservation.future?
          "future"
        else
          "past"
        end
      end
    end
  end
end
