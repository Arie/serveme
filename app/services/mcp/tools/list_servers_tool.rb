# typed: strict
# frozen_string_literal: true

module Mcp
  module Tools
    class ListServersTool < BaseTool
      extend T::Sig

      sig { override.returns(String) }
      def self.tool_name
        "list_servers"
      end

      sig { override.returns(String) }
      def self.description
        "List all game servers with their current status. " \
        "Shows server details, location, and optionally current reservation information."
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def self.input_schema
        {
          type: "object",
          properties: {
            active_only: {
              type: "boolean",
              description: "Only return active servers. Default: true",
              default: true
            },
            include_reservation: {
              type: "boolean",
              description: "Include current reservation information. Default: false",
              default: false
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
        active_only = params.fetch(:active_only, true)
        include_reservation = params.fetch(:include_reservation, false)

        servers = active_only ? Server.active : Server.all
        servers = servers.includes(:location, :groups)
        servers = servers.includes(current_reservations: :user) if include_reservation
        servers = servers.order(:name)

        {
          servers: servers.map { |s| format_server(s, include_reservation) },
          total_count: servers.size
        }
      end

      private

      sig { params(server: Server, include_reservation: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
      def format_server(server, include_reservation)
        result = {
          id: server.id,
          name: server.name,
          ip: server.ip,
          port: server.port,
          active: server.active,
          location: server.location&.name,
          location_flag: server.location_flag,
          groups: server.groups.pluck(:name),
          sdr: server.sdr?,
          last_known_version: server.last_known_version,
          update_status: server.update_status
        }

        if include_reservation
          current = server.current_reservation
          result[:current_reservation] = current ? format_reservation(current) : nil
        end

        result
      end

      sig { params(reservation: Reservation).returns(T::Hash[Symbol, T.untyped]) }
      def format_reservation(reservation)
        {
          id: reservation.id,
          user_id: reservation.user_id,
          user_nickname: reservation.user&.nickname,
          starts_at: reservation.starts_at,
          ends_at: reservation.ends_at,
          status: reservation.status
        }
      end
    end
  end
end
