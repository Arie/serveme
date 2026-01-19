# typed: strict
# frozen_string_literal: true

module Mcp
  module Tools
    class GetUserTool < BaseTool
      extend T::Sig

      sig { override.returns(String) }
      def self.tool_name
        "get_user"
      end

      sig { override.returns(String) }
      def self.description
        "Look up a user by Steam ID, nickname, or user ID. " \
        "Returns detailed user information including reservation history, " \
        "donator status, and group memberships."
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def self.input_schema
        {
          type: "object",
          properties: {
            query: {
              type: "string",
              description: "Search query: Steam ID64 (76561198...), Steam ID (STEAM_0:0:123), " \
                          "Steam ID3 ([U:1:123]), user ID (#123 or just 123), " \
                          "Steam profile URL, or nickname"
            }
          },
          required: [ "query" ]
        }
      end

      sig { override.returns(Symbol) }
      def self.required_role
        :admin
      end

      sig { override.params(params: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def execute(params)
        query = params[:query]&.to_s&.strip

        if query.blank?
          return { user: nil, error: "Query parameter is required" }
        end

        results = UserSearchService.new(query).search

        if results.empty?
          return { user: nil, error: "User not found for query: #{query}" }
        end

        if results.size == 1
          { user: format_user(T.must(results.first)) }
        else
          { users: results.map { |u| format_user(u) } }
        end
      end

      private

      sig { params(user: User).returns(T::Hash[Symbol, T.untyped]) }
      def format_user(user)
        {
          id: user.id,
          uid: user.uid,
          nickname: user.nickname,
          name: user.name,
          donator: user.donator?,
          donator_until: user.donator_until,
          admin: user.admin?,
          league_admin: user.league_admin?,
          groups: user.groups.pluck(:name),
          reservation_count: user.reservations.count,
          created_at: user.created_at,
          current_reservation: format_current_reservation(user),
          steam_profile_url: "https://steamcommunity.com/profiles/#{user.uid}"
        }
      end

      sig { params(user: User).returns(T.nilable(T::Hash[Symbol, T.untyped])) }
      def format_current_reservation(user)
        reservation = Reservation.current.where(user_id: user.id).first
        return nil unless reservation

        {
          id: reservation.id,
          server_name: reservation.server&.name,
          starts_at: reservation.starts_at,
          ends_at: reservation.ends_at
        }
      end
    end
  end
end
