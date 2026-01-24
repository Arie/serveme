# typed: false
# frozen_string_literal: true

module ServemeBot
  module Commands
    class ReserveCommand < BaseCommand
      DEFAULT_DURATION = 120 # 2 hours
      DEFAULT_MAP = "cp_badlands"

      def execute(server_query: nil, map: nil, password: nil, duration: nil, config: nil, whitelist: nil)
        log_command("book", server: server_query, map: map, duration: duration, config: config, whitelist: whitelist)
        return unless require_linked_account!

        defer_response

        # Calculate times
        duration_minutes = [ duration || DEFAULT_DURATION, 30 ].max
        starts_at = Time.current
        ends_at = starts_at + duration_minutes.minutes

        # Check user's max duration
        max_minutes = current_user.maximum_reservation_length / 60
        if duration_minutes > max_minutes
          edit_response(content: ":x: Duration exceeds your maximum of #{max_minutes} minutes")
          return
        end

        # Use IAmFeelingLucky for smart defaults
        lucky = IAmFeelingLucky.new(current_user)
        previous = lucky.previous_reservation

        # Find server - fuzzy match if query provided, otherwise use lucky logic
        server = find_server(server_query, starts_at, ends_at, lucky)
        return unless server

        # Determine password - use provided, or previous, or generate
        password = password.to_s.strip
        if password.blank?
          password = previous&.password.presence || SecureRandom.alphanumeric(8)
        elsif password.length > 60
          edit_response(content: ":x: Password too long (max 60 characters)")
          return
        end

        # Determine map - use provided, or previous, or default
        first_map = map.presence || previous&.first_map.presence || DEFAULT_MAP

        # Look up server config by name if provided
        server_config_id = find_server_config_id(config, previous)
        return unless server_config_id != :error

        # Look up whitelist by name if provided, or treat as custom whitelist.tf ID
        whitelist_settings = resolve_whitelist(whitelist, previous)

        # Build reservation with smart defaults from previous
        reservation = current_user.reservations.build(
          server: server,
          starts_at: starts_at,
          ends_at: ends_at,
          password: password,
          rcon: previous&.rcon.presence || SecureRandom.alphanumeric(12),
          tv_password: previous&.tv_password.presence || SecureRandom.alphanumeric(8),
          first_map: first_map,
          server_config_id: server_config_id,
          whitelist_id: whitelist_settings[:whitelist_id],
          custom_whitelist_id: whitelist_settings[:custom_whitelist_id],
          enable_plugins: previous&.enable_plugins? || false,
          enable_demos_tf: previous&.enable_demos_tf? || false,
          auto_end: true
        )

        unless reservation.valid?
          edit_response(content: ":x: #{reservation.errors.full_messages.join(', ')}")
          return
        end

        # Save with lock to prevent race conditions
        begin
          $lock.synchronize("save-reservation-server-#{server.id}") do
            reservation.save!
          end
        rescue ActiveRecord::RecordInvalid => e
          edit_response(content: ":x: #{e.message}")
          return
        end

        # Start immediately since it's a "now" reservation
        if reservation.persisted? && reservation.now?
          reservation.update_attribute(:start_instantly, true)
          reservation.start_reservation
        end

        # Respond to interaction first (required within 15 min)
        # Include RCON here since only the creator sees this ephemeral message
        edit_response(content: ":white_check_mark: Reservation created! Setting up server...\n\n**RCON:** ||`#{reservation.rcon}`||")

        # Send a bot-owned message that we can edit indefinitely
        embed = format_reservation_embed(reservation, "starting")
        rcon_url = "#{SITE_URL}/reservations/#{reservation.id}/rcon"
        buttons = Discordrb::Components::View.new do |v|
          v.row do |r|
            r.button(style: :danger, label: "End", custom_id: "end_reservation:#{reservation.id}")
            r.button(style: :primary, label: "Extend", custom_id: "extend_reservation:#{reservation.id}")
            r.button(style: :link, label: "RCON", url: rcon_url)
          end
        end
        message = event.channel.send_message("", false, embed, nil, nil, nil, buttons)

        # Save Discord message info to reservation for Sidekiq-based updates
        reservation.update_columns(
          discord_channel_id: event.channel.id.to_s,
          discord_message_id: message.id.to_s
        )
      rescue StandardError => e
        Rails.logger.error "ReserveCommand error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        edit_response(content: ":x: Failed to create reservation. Please try again later.")
      end

      private

      def find_server(server_query, starts_at, ends_at, lucky)
        available_servers = ServerForUserFinder.new(current_user, starts_at, ends_at).servers

        if available_servers.empty?
          edit_response(content: ":x: No servers available. Try again later or choose a different time.")
          return nil
        end

        if server_query.present?
          # Fuzzy match server name
          query = server_query.to_s.downcase
          matched = available_servers.find { |s| s.name.downcase.include?(query) }

          unless matched
            # Try matching by location
            matched = available_servers.find { |s| s.location&.name&.downcase&.include?(query) }
          end

          unless matched
            server_names = available_servers.first(5).map(&:name).join(", ")
            edit_response(content: ":x: No available server matching '#{server_query}'.\n\nAvailable: #{server_names}")
            return nil
          end

          matched
        else
          # Use IAmFeelingLucky logic - prefer previous host/location
          lucky.best_matching_server || available_servers.first
        end
      end

      def find_server_config_id(config_query, previous)
        # Explicit "no config" - don't use previous
        return nil if config_query == "__none__"

        # No query - use previous config if available
        return previous&.server_config_id if config_query.blank?

        query = config_query.to_s.downcase
        config = ServerConfig.active.find { |c| c.file.downcase.include?(query) }

        unless config
          available = ServerConfig.active.ordered.first(5).map(&:file).join(", ")
          edit_response(content: ":x: No config matching '#{config_query}'.\n\nExamples: #{available}")
          return :error
        end

        config.id
      end

      def resolve_whitelist(whitelist_query, previous)
        # No query provided - use previous settings
        if whitelist_query.blank?
          return {
            whitelist_id: previous&.whitelist_id,
            custom_whitelist_id: previous&.custom_whitelist_id
          }
        end

        query = whitelist_query.to_s.strip

        # First try to find a matching local whitelist by name
        whitelist = Whitelist.active.find { |w| w.file.downcase.include?(query.downcase) }

        if whitelist
          # Found a local whitelist - use its ID
          { whitelist_id: whitelist.id, custom_whitelist_id: nil }
        else
          # No match - assume it's a custom whitelist.tf ID
          { whitelist_id: nil, custom_whitelist_id: query }
        end
      end

      def apply_embed(embed_builder, embed_hash)
        embed_builder.title = embed_hash[:title]
        embed_builder.color = embed_hash[:color]
        embed_builder.timestamp = Time.now

        embed_hash[:fields]&.each do |field|
          embed_builder.add_field(
            name: field[:name],
            value: field[:value],
            inline: field[:inline]
          )
        end

        if embed_hash[:footer]
          embed_builder.footer = Discordrb::Webhooks::EmbedFooter.new(text: embed_hash[:footer][:text])
        end
      end

      def format_reservation_embed(reservation, status = nil)
        server = reservation.server
        status ||= "starting"

        color = case status
        when "ready" then 0x57F287 # Green
        when "starting" then 0xFEE75C # Yellow
        when "ended" then 0x99AAB5 # Gray
        else 0x5865F2 # Blue
        end

        status_text = case status
        when "ready" then ":green_circle: Server Ready"
        when "starting" then ":yellow_circle: Starting..."
        when "ended" then ":white_circle: Ended"
        else ":blue_circle: #{status.capitalize}"
        end

        connect_string = server.server_connect_string(reservation.password)
        stv_connect_string = server.stv_connect_string(reservation.tv_password)
        config_name = reservation.server_config&.file || "None"
        whitelist_name = reservation.whitelist&.file || reservation.custom_whitelist_id || "None"

        fields = [
          Discordrb::Webhooks::EmbedField.new(name: "Status", value: status_text, inline: true),
          Discordrb::Webhooks::EmbedField.new(name: "Map", value: reservation.first_map, inline: true),
          Discordrb::Webhooks::EmbedField.new(name: "Players", value: "0/24", inline: true),
          Discordrb::Webhooks::EmbedField.new(name: "Ends", value: "<t:#{reservation.ends_at.to_i}:R>", inline: true),
          Discordrb::Webhooks::EmbedField.new(name: "Config", value: config_name, inline: true),
          Discordrb::Webhooks::EmbedField.new(name: "Whitelist", value: whitelist_name, inline: true),
          Discordrb::Webhooks::EmbedField.new(name: "Connect", value: "```#{connect_string}```", inline: false),
          Discordrb::Webhooks::EmbedField.new(name: "Password", value: "`#{reservation.password}`", inline: true),
          Discordrb::Webhooks::EmbedField.new(name: "STV", value: "```#{stv_connect_string}```", inline: false)
        ]

        flag = Helpers::FlagHelper.to_discord_emoji(server.location_flag)
        Discordrb::Webhooks::Embed.new(
          title: "#{flag} #{server.name}",
          color: color,
          fields: fields,
          footer: Discordrb::Webhooks::EmbedFooter.new(text: "Reservation ##{reservation.id}"),
          timestamp: Time.now
        )
      end
    end
  end
end
