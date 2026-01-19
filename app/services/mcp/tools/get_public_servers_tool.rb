# typed: strict
# frozen_string_literal: true

module Mcp
  module Tools
    class GetPublicServersTool < BaseTool
      extend T::Sig

      sig { override.returns(String) }
      def self.tool_name
        "get_public_servers"
      end

      sig { override.returns(String) }
      def self.description
        "List available game servers with their current status. " \
        "Shows which servers are free or occupied. " \
        "Public endpoint - no sensitive data returned."
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def self.input_schema
        {
          type: "object",
          properties: {
            location: {
              type: "string",
              description: "Filter by location name (e.g., 'Netherlands', 'Germany', 'Chicago')"
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
        servers = Server.active

        if params[:location].present?
          location = Location.where("name ILIKE ?", "%#{params[:location]}%").first
          servers = servers.where(location: location) if location
        end

        servers = servers.includes(:location, :current_reservations)

        formatted_servers = servers.map { |s| format_server(s) }

        {
          servers: formatted_servers,
          server_count: formatted_servers.size
        }
      end

      private

      sig { params(server: Server).returns(T::Hash[Symbol, T.untyped]) }
      def format_server(server)
        # current_reservations is preloaded, .first gives us the current reservation if any
        current_reservation = server.current_reservations.first

        {
          id: server.id,
          name: server.name,
          location: server.location&.name,
          flag: server.location&.flag,
          available: current_reservation.nil?,
          busy_until: current_reservation&.ends_at
        }
      end
    end
  end
end
