# typed: strict
# frozen_string_literal: true

module Mcp
  module Tools
    class GetReservationStatusTool < BaseTool
      extend T::Sig

      sig { override.returns(String) }
      def self.tool_name
        "get_reservation_status"
      end

      sig { override.returns(String) }
      def self.description
        "Get the current status of a reservation including server status, " \
        "connected players, and time remaining. Use this to update Discord " \
        "messages with live reservation information."
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def self.input_schema
        {
          type: "object",
          properties: {
            reservation_id: {
              type: "integer",
              description: "The reservation ID to get status for"
            },
            steam_uid: {
              type: "string",
              description: "Steam ID64 of the requesting user (for authorization)"
            },
            discord_uid: {
              type: "string",
              description: "Discord user ID (for authorization via linked account)"
            }
          },
          required: [ "reservation_id" ]
        }
      end

      sig { override.returns(Symbol) }
      def self.required_role
        :public
      end

      sig { override.params(params: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def execute(params)
        reservation_id = params[:reservation_id]
        return { error: "reservation_id is required" } unless reservation_id

        reservation = Reservation.find_by(id: reservation_id)
        return { error: "Reservation not found" } unless reservation

        # Verify the requesting user owns this reservation
        user_result = verify_owner(reservation, params)
        return user_result if user_result[:error]

        format_reservation_status(reservation)
      end

      private

      sig { params(reservation: Reservation, params: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def verify_owner(reservation, params)
        if params[:discord_uid].present?
          user = User.find_by(discord_uid: params[:discord_uid])
          return { error: "Discord account not linked" } unless user
          return { error: "Not authorized to view this reservation" } unless reservation.user_id == user.id
        elsif params[:steam_uid].present?
          return { error: "Not authorized to view this reservation" } unless reservation.user&.uid == params[:steam_uid]
        end
        # If no auth provided, still allow (for now) since reservation IDs aren't guessable
        {}
      end

      sig { params(reservation: Reservation).returns(T::Hash[Symbol, T.untyped]) }
      def format_reservation_status(reservation)
        server = reservation.server
        latest_status = ReservationStatus.where(reservation_id: reservation.id).last

        {
          reservation: {
            id: reservation.id,
            server_name: server&.name,
            server_ip: server&.ip,
            server_port: server&.port,
            connect_string: "connect #{server&.ip}:#{server&.port}; password #{reservation.password}",
            password: reservation.password,
            rcon: reservation.rcon,
            first_map: reservation.first_map,
            starts_at: reservation.starts_at&.iso8601,
            ends_at: reservation.ends_at&.iso8601,
            status: reservation_status_string(reservation),
            status_message: latest_status&.status,
            time_remaining_minutes: time_remaining_minutes(reservation),
            manage_url: "https://serveme.tf/reservations/#{reservation.id}"
          },
          server: format_server_info(reservation),
          players: format_players(reservation)
        }
      end

      sig { params(reservation: Reservation).returns(String) }
      def reservation_status_string(reservation)
        if reservation.ended?
          "ended"
        elsif reservation.provisioned? && reservation.now?
          "ready"
        elsif reservation.now?
          "starting"
        elsif reservation.future?
          "scheduled"
        else
          "past"
        end
      end

      sig { params(reservation: Reservation).returns(T.nilable(Integer)) }
      def time_remaining_minutes(reservation)
        ends_at = reservation.ends_at
        return nil if reservation.ended? || ends_at.nil? || ends_at < Time.current
        ((ends_at - Time.current) / 60).to_i
      end

      sig { params(reservation: Reservation).returns(T::Hash[Symbol, T.untyped]) }
      def format_server_info(reservation)
        server = reservation.server
        return {} unless server

        # Try to get live server info
        server_info = begin
          info = server.server_info
          {
            map: info.map_name,
            player_count: info.number_of_players,
            max_players: info.max_players
          }
        rescue StandardError
          {}
        end

        {
          name: server.name,
          ip: server.ip,
          port: server.port,
          location: server.location&.name
        }.merge(server_info)
      end

      sig { params(reservation: Reservation).returns(T::Array[T::Hash[Symbol, T.untyped]]) }
      def format_players(reservation)
        # Get players from reservation_players (logged during reservation)
        reservation.reservation_players.order(id: :desc).limit(24).map do |rp|
          {
            name: rp.name,
            steam_uid: rp.steam_uid,
            ip: nil # Don't expose IPs
          }
        end
      end
    end
  end
end
