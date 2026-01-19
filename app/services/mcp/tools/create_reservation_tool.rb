# typed: strict
# frozen_string_literal: true

module Mcp
  module Tools
    class CreateReservationTool < BaseTool
      extend T::Sig

      sig { override.returns(String) }
      def self.tool_name
        "create_reservation"
      end

      sig { override.returns(String) }
      def self.description
        "Create a new server reservation. Requires a linked Discord account or Steam ID. " \
        "Server will be auto-selected if not specified. Returns reservation details including " \
        "server IP, password, and RCON."
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def self.input_schema
        {
          type: "object",
          properties: {
            steam_uid: {
              type: "string",
              description: "Steam ID64 of the player making the reservation"
            },
            discord_uid: {
              type: "string",
              description: "Discord user ID (requires linked account)"
            },
            server_id: {
              type: "integer",
              description: "Server ID to reserve. If not provided, auto-selects first available server."
            },
            duration_minutes: {
              type: "integer",
              description: "Duration in minutes. Default: 120 (2 hours). Max depends on user tier.",
              default: 120
            },
            password: {
              type: "string",
              description: "Server password. Required."
            },
            rcon: {
              type: "string",
              description: "RCON password. Auto-generated if not provided."
            },
            first_map: {
              type: "string",
              description: "Initial map. Default: cp_badlands"
            },
            server_config_id: {
              type: "integer",
              description: "Server config ID to apply"
            },
            whitelist_id: {
              type: "integer",
              description: "Whitelist ID to apply"
            },
            enable_plugins: {
              type: "boolean",
              description: "Enable SourceMod plugins. Default: false"
            },
            enable_demos_tf: {
              type: "boolean",
              description: "Enable demos.tf recording. Default: false"
            }
          },
          required: [ "password" ]
        }
      end

      sig { override.returns(Symbol) }
      def self.required_role
        :public
      end

      sig { override.params(params: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def execute(params)
        # Find user
        user_result = find_user(params)
        return user_result if user_result[:error]

        target_user = T.cast(user_result[:user], User)

        # Validate password
        password = params[:password]&.to_s&.strip
        return { error: "Password is required" } if password.blank?
        return { error: "Password too long (max 60 characters)" } if password.length > 60

        # Calculate times
        duration_minutes = [ params.fetch(:duration_minutes, 120).to_i, 30 ].max
        starts_at = Time.current
        ends_at = starts_at + duration_minutes.minutes

        # Check user's max duration
        max_minutes = target_user.maximum_reservation_length / 60
        if duration_minutes > max_minutes
          return { error: "Duration exceeds your maximum of #{max_minutes} minutes" }
        end

        # Find or validate server
        server_result = find_server(target_user, params[:server_id], starts_at, ends_at)
        return server_result if server_result[:error]

        server = T.cast(server_result[:server], Server)

        # Build reservation
        reservation = target_user.reservations.build(
          server: server,
          starts_at: starts_at,
          ends_at: ends_at,
          password: password,
          rcon: params[:rcon].presence || generate_rcon,
          first_map: params[:first_map].presence || "cp_badlands",
          server_config_id: params[:server_config_id],
          whitelist_id: params[:whitelist_id],
          enable_plugins: params[:enable_plugins] || false,
          enable_demos_tf: params[:enable_demos_tf] || false,
          auto_end: true
        )

        unless reservation.valid?
          return { error: reservation.errors.full_messages.join(", ") }
        end

        # Save with lock to prevent race conditions
        begin
          $lock.synchronize("save-reservation-server-#{server.id}") do
            reservation.save!
          end
        rescue ActiveRecord::RecordInvalid => e
          return { error: e.message }
        end

        # Start immediately since it's a "now" reservation
        if reservation.persisted? && reservation.now?
          reservation.update_attribute(:start_instantly, true)
          reservation.start_reservation
        end

        format_created_reservation(reservation)
      end

      private

      sig { params(params: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def find_user(params)
        if params[:discord_uid].present?
          user = User.find_by(discord_uid: params[:discord_uid])
          return { error: "Discord account not linked. Use /link command first." } unless user
          { user: user }
        elsif params[:steam_uid].present?
          user = User.find_by(uid: params[:steam_uid])
          return { error: "No account found for Steam ID: #{params[:steam_uid]}" } unless user
          { user: user }
        else
          { error: "Either steam_uid or discord_uid is required" }
        end
      end

      sig { params(user: User, server_id: T.nilable(Integer), starts_at: ActiveSupport::TimeWithZone, ends_at: ActiveSupport::TimeWithZone).returns(T::Hash[Symbol, T.untyped]) }
      def find_server(user, server_id, starts_at, ends_at)
        if server_id.present?
          server = Server.find_by(id: server_id)
          return { error: "Server not found" } unless server

          # Check if user can reserve this server
          available_servers = ServerForUserFinder.new(user, starts_at, ends_at).servers
          unless available_servers.include?(server)
            return { error: "Server #{server.name} is not available for you at this time" }
          end

          { server: server }
        else
          # Auto-select first available server
          servers = ServerForUserFinder.new(user, starts_at, ends_at).servers
          return { error: "No servers available. Try again later or choose a different time." } if servers.empty?

          { server: servers.first }
        end
      end

      sig { returns(String) }
      def generate_rcon
        SecureRandom.alphanumeric(12)
      end

      sig { params(reservation: Reservation).returns(Integer) }
      def calculate_duration_minutes(reservation)
        ends_at = reservation.ends_at
        starts_at = reservation.starts_at
        return 0 unless ends_at && starts_at
        ((ends_at - starts_at) / 60).to_i
      end

      sig { params(reservation: Reservation).returns(T::Hash[Symbol, T.untyped]) }
      def format_created_reservation(reservation)
        server = reservation.server

        {
          success: true,
          reservation: {
            id: reservation.id,
            server_name: server&.name,
            server_ip: server&.ip,
            server_port: server&.port,
            connect_string: "connect #{server&.ip}:#{server&.port}; password #{reservation.password}",
            password: reservation.password,
            rcon: reservation.rcon,
            starts_at: reservation.starts_at&.iso8601,
            ends_at: reservation.ends_at&.iso8601,
            duration_minutes: calculate_duration_minutes(reservation),
            first_map: reservation.first_map,
            status: "starting",
            manage_url: "#{SITE_URL}/reservations/#{reservation.id}"
          }
        }
      end
    end
  end
end
