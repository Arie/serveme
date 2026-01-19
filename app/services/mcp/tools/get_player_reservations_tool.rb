# typed: strict
# frozen_string_literal: true

module Mcp
  module Tools
    class GetPlayerReservationsTool < BaseTool
      extend T::Sig

      sig { override.returns(String) }
      def self.tool_name
        "get_player_reservations"
      end

      sig { override.returns(String) }
      def self.description
        "Get a player's reservation history by Steam ID or Discord ID. " \
        "Returns non-sensitive reservation data (no passwords or RCON). " \
        "Use discord_uid for Discord bot integration."
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def self.input_schema
        {
          type: "object",
          properties: {
            steam_uid: {
              type: "string",
              description: "Steam ID64 of the player"
            },
            discord_uid: {
              type: "string",
              description: "Discord user ID (for Discord bot integration - requires linked account)"
            },
            status: {
              type: "string",
              enum: [ "current", "future", "past", "all" ],
              description: "Filter by reservation status. Default: all"
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
        :public
      end

      sig { override.params(params: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def execute(params)
        player = find_player(params)
        return player if player[:error]

        target_user = T.cast(player[:user], User)
        reservations = build_query(target_user, params)
        limit = [ params.fetch(:limit, 25).to_i, 100 ].min

        reservations = reservations.limit(limit)

        {
          player: format_player(target_user),
          reservations: reservations.map { |r| format_reservation(r) },
          total_count: reservations.size
        }
      end

      private

      sig { params(params: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def find_player(params)
        if params[:discord_uid].present?
          player = User.find_by(discord_uid: params[:discord_uid])
          return { error: "Discord account not linked to serveme.tf. Use /link command first." } unless player

          { user: player }
        elsif params[:steam_uid].present?
          player = User.find_by(uid: params[:steam_uid])
          return { error: "Player not found for Steam ID: #{params[:steam_uid]}" } unless player

          { user: player }
        else
          { error: "Either steam_uid or discord_uid is required" }
        end
      end

      sig { params(target_user: User, params: T::Hash[Symbol, T.untyped]).returns(ActiveRecord::Relation) }
      def build_query(target_user, params)
        reservations = Reservation.where(user_id: target_user.id).includes(:server)

        case params[:status]&.to_s
        when "current"
          reservations = reservations.where(starts_at: ..Time.current).where(ends_at: Time.current..)
        when "future"
          reservations = reservations.where(starts_at: Time.current..)
        when "past"
          reservations = reservations.where(ends_at: ...Time.current)
        end

        reservations.order(starts_at: :desc)
      end

      sig { params(player: User).returns(T::Hash[Symbol, T.untyped]) }
      def format_player(player)
        {
          nickname: player.nickname,
          steam_uid: player.uid,
          steam_profile_url: "https://steamcommunity.com/profiles/#{player.uid}",
          reservation_count: player.reservations.count
        }
      end

      sig { params(reservation: Reservation).returns(T::Hash[Symbol, T.untyped]) }
      def format_reservation(reservation)
        {
          id: reservation.id,
          server_name: reservation.server&.name,
          starts_at: reservation.starts_at,
          ends_at: reservation.ends_at,
          status: reservation_status(reservation),
          first_map: reservation.first_map
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
