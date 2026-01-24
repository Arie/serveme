#!/usr/bin/env ruby
# typed: false
# frozen_string_literal: true

# Load Rails environment first (like Sidekiq does)
ENV["RAILS_ENV"] ||= ENV.fetch("BOT_ENV", "development")
require_relative "../config/environment"

# Now load Discord
require "discordrb"

# Load bot libraries
require_relative "lib/config"
require_relative "lib/helpers/flag_helper"
require_relative "lib/helpers/regional_configs"
require_relative "lib/formatters/server_formatter"
require_relative "lib/formatters/reservation_formatter"
require_relative "lib/commands/base_command"
require_relative "lib/commands/servers_command"
require_relative "lib/commands/reservations_command"
require_relative "lib/commands/link_command"
require_relative "lib/commands/reserve_command"

module ServemeBot
  class Bot
    def initialize
      ServemeBot::Config.load

      @bot = Discordrb::Bot.new(
        token: Config.discord_token,
        client_id: Config.discord_client_id,
        intents: [ :server_messages ]
      )

      register_commands
    end

    def run
      puts "Starting serveme.tf Discord bot..."
      puts "Environment: #{Rails.env}"
      puts "Invite URL: #{@bot.invite_url}"

      setup_signal_handlers
      @bot.run
    end

    def stop
      puts "Stopping Discord bot..."
      @bot.stop
    end

    private

    def setup_signal_handlers
      %w[INT TERM].each do |signal|
        trap(signal) do
          puts "Received #{signal}, shutting down gracefully..."
          stop
        end
      end
    end

    def register_commands
      # Use guild commands in development for instant updates (no rate limit)
      # Global commands can take up to an hour to propagate
      server_id = Config.dev_guild_id

      if server_id
        puts "Using guild commands for server #{server_id} (development mode)"
      else
        puts "Using global commands (production mode)"
      end

      register_button_handlers

      # Register command with all subcommands (region-specific: /serveme, /serveme-na, etc.)
      @bot.register_application_command(Config.command_name, "#{Config.bot_name} - TF2 server reservations", server_id: server_id) do |cmd|
        cmd.subcommand(:servers, "Show available servers")

        cmd.subcommand(:reservations, "Show your reservation history") do |sub|
          sub.string(:status, "Filter by status", required: false,
            choices: { "Current" => "current", "Future" => "future", "Past" => "past" })
          sub.integer(:limit, "Number of results (default: 10)", required: false)
        end

        cmd.subcommand(:book, "Book a TF2 server") do |sub|
          sub.string(:server, "Server name", required: false, autocomplete: true)
          sub.string(:map, "Initial map (uses previous or cp_badlands)", required: false, autocomplete: true)
          sub.string(:password, "Server password (uses previous or auto-generated)", required: false)
          sub.integer(:duration, "Duration in minutes (default: 120)", required: false, autocomplete: true)
          sub.string(:config, "Server config", required: false, autocomplete: true)
          sub.string(:whitelist, "Whitelist", required: false, autocomplete: true)
        end

        cmd.subcommand(:reserve, "Book a TF2 server (alias for book)") do |sub|
          sub.string(:server, "Server name", required: false, autocomplete: true)
          sub.string(:map, "Initial map (uses previous or cp_badlands)", required: false, autocomplete: true)
          sub.string(:password, "Server password (uses previous or auto-generated)", required: false)
          sub.integer(:duration, "Duration in minutes (default: 120)", required: false, autocomplete: true)
          sub.string(:config, "Server config", required: false, autocomplete: true)
          sub.string(:whitelist, "Whitelist", required: false, autocomplete: true)
        end

        cmd.subcommand(:link, "Link your Discord to serveme.tf")

        cmd.subcommand(:unlink, "Unlink your Discord from serveme.tf")

        cmd.subcommand(:help, "Show available commands")
      end

      # Handle subcommands
      @bot.application_command(Config.command_name).subcommand(:servers) do |event|
        Commands::ServersCommand.new(event).execute
      end

      @bot.application_command(Config.command_name).subcommand(:reservations) do |event|
        Commands::ReservationsCommand.new(event).execute(
          status: event.options["status"],
          limit: event.options["limit"] || 10
        )
      end

      @bot.application_command(Config.command_name).subcommand(:book) do |event|
        Commands::ReserveCommand.new(event).execute(
          server_query: event.options["server"],
          map: event.options["map"],
          password: event.options["password"],
          duration: event.options["duration"],
          config: event.options["config"],
          whitelist: event.options["whitelist"]
        )
      end

      @bot.application_command(Config.command_name).subcommand(:reserve) do |event|
        Commands::ReserveCommand.new(event).execute(
          server_query: event.options["server"],
          map: event.options["map"],
          password: event.options["password"],
          duration: event.options["duration"],
          config: event.options["config"],
          whitelist: event.options["whitelist"]
        )
      end

      @bot.application_command(Config.command_name).subcommand(:link) do |event|
        Commands::LinkCommand.new(event).execute
      end

      @bot.application_command(Config.command_name).subcommand(:unlink) do |event|
        Commands::LinkCommand.new(event).execute(unlink: true)
      end

      @bot.application_command(Config.command_name).subcommand(:help) do |event|
        user = User.find_by(discord_uid: event.user.id.to_s)
        user_info = user ? "#{user.nickname} (#{user.id})" : "unlinked"
        Rails.logger.info "[Discord] help by #{event.user.username} (#{event.user.id}) -> #{user_info}"

        cmd = Config.command_name
        help_text = <<~HELP
          **#{Config.bot_name} Discord Bot**

          `/#{cmd} book` - Book a TF2 server
          Options: `server`, `map`, `password`, `duration`, `config`, `whitelist`
          All options are optional - uses your previous settings if not specified.

          `/#{cmd} servers` - Show available #{Config.region_name} servers
          `/#{cmd} reservations` - Show your reservation history
          `/#{cmd} link` - Link your Discord to #{SITE_HOST}
          `/#{cmd} unlink` - Unlink your Discord account

          Visit #{Config.site_url} for more info.
        HELP
        event.respond(content: help_text, ephemeral: true)
      end

      # Register autocomplete handlers AFTER command registration
      register_autocomplete_handlers
    end

    def register_button_handlers
      # End reservation button
      @bot.button(custom_id: /^end_reservation:\d+$/) do |event|
        reservation_id = event.interaction.button.custom_id.split(":").last.to_i
        handle_end_reservation(event, reservation_id)
      end

      # Extend reservation button
      @bot.button(custom_id: /^extend_reservation:\d+$/) do |event|
        reservation_id = event.interaction.button.custom_id.split(":").last.to_i
        handle_extend_reservation(event, reservation_id)
      end

      # Book server group button (from /serveme servers)
      @bot.button(custom_id: /^book_group:.+$/) do |event|
        group_name = event.interaction.button.custom_id.sub("book_group:", "")
        handle_book_group(event, group_name)
      end

      # Book with config button (from config preset selection)
      @bot.button(custom_id: /^book_with_config:.+$/) do |event|
        parts = event.interaction.button.custom_id.sub("book_with_config:", "").split(":", 2)
        group_name = parts[0]
        config_name = parts[1] || ""
        handle_book_with_config(event, group_name, config_name)
      end
    end

    def register_autocomplete_handlers
      @bot.autocomplete do |event|
        case event.focused
        when "server"
          handle_server_autocomplete(event)
        when "map"
          handle_map_autocomplete(event)
        when "config"
          handle_config_autocomplete(event)
        when "whitelist"
          handle_whitelist_autocomplete(event)
        when "duration"
          handle_duration_autocomplete(event)
        else
          event.respond(choices: [])
        end
      end
    end

    def handle_server_autocomplete(event)
      user = User.find_by(discord_uid: event.user.id.to_s)
      return event.respond(choices: []) unless user

      query = (event.options[event.focused] || "").to_s.downcase

      # Only show currently available servers (not reserved)
      starts_at = Time.current
      ends_at = starts_at + 2.hours
      servers = ServerForUserFinder.new(user, starts_at, ends_at).servers.includes(:location)

      suggestions = servers.order(:name).map do |s|
        { name: "#{s.name} (#{s.location&.name || 'Unknown'})", value: s.name }
      end

      if query.present?
        suggestions = suggestions.select { |s| s[:name].downcase.include?(query) }
      end

      event.respond(choices: suggestions.first(25))
    rescue StandardError => e
      Rails.logger.error "Server autocomplete error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      event.respond(choices: [])
    end

    def handle_map_autocomplete(event)
      user = User.find_by(discord_uid: event.user.id.to_s)
      return event.respond(choices: []) unless user

      query = (event.options[event.focused] || "").to_s.downcase

      # User's recent maps (from last 20 reservations)
      recent_maps = user.reservations
        .where.not(first_map: [ nil, "" ])
        .order(created_at: :desc)
        .limit(20)
        .pluck(:first_map)
        .uniq

      # League maps as fallback
      league_maps = LeagueMaps.all_league_maps

      # Combine and sort alphabetically
      all_maps = (recent_maps + league_maps).uniq.sort

      suggestions = all_maps.map { |m| { name: m, value: m } }

      if query.present?
        suggestions = suggestions.select { |s| s[:name].downcase.include?(query) }
      end

      event.respond(choices: suggestions.first(25))
    rescue StandardError => e
      Rails.logger.error "Map autocomplete error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      event.respond(choices: [])
    end

    def handle_config_autocomplete(event)
      user = User.find_by(discord_uid: event.user.id.to_s)
      return event.respond(choices: []) unless user

      query = (event.options[event.focused] || "").to_s.downcase
      configs = ServerConfig.active.ordered.to_a

      # Prioritize regional configs (ETF2L for EU, RGL for NA, etc.)
      configs = Helpers::RegionalConfigs.prioritized_configs(configs, Config.region_key)

      suggestions = configs.map { |c| { name: c.file, value: c.file } }

      if query.present?
        suggestions = suggestions.select { |s| s[:name].downcase.include?(query) }
      end

      event.respond(choices: suggestions.first(25))
    rescue StandardError => e
      Rails.logger.error "Config autocomplete error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      event.respond(choices: [])
    end

    def handle_whitelist_autocomplete(event)
      user = User.find_by(discord_uid: event.user.id.to_s)
      return event.respond(choices: []) unless user

      query = (event.options[event.focused] || "").to_s.downcase
      # Use same list as /whitelists page: non-hidden, case-insensitive order
      whitelists = Whitelist.active.ordered

      suggestions = whitelists.map { |w| { name: w.file, value: w.file } }

      if query.present?
        suggestions = suggestions.select { |s| s[:name].downcase.include?(query) }
      end

      event.respond(choices: suggestions.first(25))
    rescue StandardError => e
      Rails.logger.error "Whitelist autocomplete error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      event.respond(choices: [])
    end

    def handle_duration_autocomplete(event)
      # Predefined duration options with human-readable labels
      durations = [
        { name: "30 minutes", value: 30 },
        { name: "1 hour", value: 60 },
        { name: "1.5 hours", value: 90 },
        { name: "2 hours (default)", value: 120 },
        { name: "3 hours", value: 180 }
      ]

      query = (event.options[event.focused] || "").to_s

      if query.present?
        # Filter by typed number or text
        durations = durations.select do |d|
          d[:value].to_s.include?(query) || d[:name].downcase.include?(query.downcase)
        end
      end

      event.respond(choices: durations)
    end

    def handle_end_reservation(event, reservation_id)
      user = User.find_by(discord_uid: event.user.id.to_s)
      user_info = user ? "#{user.nickname} (#{user.id})" : "unlinked"
      Rails.logger.info "[Discord] end_reservation by #{event.user.username} (#{event.user.id}) -> #{user_info} reservation_id=#{reservation_id}"

      reservation = Reservation.find_by(id: reservation_id)
      unless reservation
        event.respond(content: ":x: Reservation not found", ephemeral: true)
        return
      end

      # Verify the user owns this reservation
      unless user && reservation.user_id == user.id
        event.respond(content: ":x: You can only end your own reservations", ephemeral: true)
        return
      end

      if reservation.ended?
        event.respond(content: ":x: Reservation already ended", ephemeral: true)
        return
      end

      # Acknowledge immediately, then process in background via Sidekiq
      event.respond(content: ":hourglass: Ending reservation...", ephemeral: true)

      # End the reservation in background (this can take 30+ seconds)
      DiscordEndReservationWorker.perform_async(
        reservation_id,
        event.interaction.token
      )
    rescue StandardError => e
      Rails.logger.error "Error ending reservation: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      event.respond(content: ":x: Failed to end reservation. Please try again later.", ephemeral: true)
    end

    def handle_extend_reservation(event, reservation_id)
      user = User.find_by(discord_uid: event.user.id.to_s)
      user_info = user ? "#{user.nickname} (#{user.id})" : "unlinked"
      Rails.logger.info "[Discord] extend_reservation by #{event.user.username} (#{event.user.id}) -> #{user_info} reservation_id=#{reservation_id}"

      reservation = Reservation.find_by(id: reservation_id)
      unless reservation
        event.respond(content: ":x: Reservation not found", ephemeral: true)
        return
      end

      # Verify the user owns this reservation
      unless user && reservation.user_id == user.id
        event.respond(content: ":x: You can only extend your own reservations", ephemeral: true)
        return
      end

      if reservation.ended?
        event.respond(content: ":x: Cannot extend an ended reservation", ephemeral: true)
        return
      end

      # Check if user can extend (requires less than 1 hour left)
      # extend! triggers DiscordReservationUpdateWorker to update the message
      unless reservation.extend!
        event.respond(content: ":x: Cannot extend reservation (requires less than 1 hour remaining, or may conflict with another booking)", ephemeral: true)
        return
      end

      event.respond(content: ":white_check_mark: Reservation extended to #{reservation.ends_at.strftime('%H:%M')}", ephemeral: true)
    rescue StandardError => e
      Rails.logger.error "Error extending reservation: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      event.respond(content: ":x: Failed to extend reservation. Please try again later.", ephemeral: true)
    end

    def handle_book_group(event, group_name)
      user = User.find_by(discord_uid: event.user.id.to_s)
      user_info = user ? "#{user.nickname} (#{user.id})" : "unlinked"
      Rails.logger.info "[Discord] book_group by #{event.user.username} (#{event.user.id}) -> #{user_info} group=#{group_name}"

      unless user
        event.respond(content: ":x: Your Discord account is not linked. Use `/#{Config.command_name} link` first.", ephemeral: true)
        return
      end

      # Always show config selection
      previous = IAmFeelingLucky.new(user).previous_reservation
      show_config_presets(event, group_name, previous&.server_config)
    end

    def show_config_presets(event, group_name, previous_config)
      presets = Helpers::RegionalConfigs.presets_for_region(Config.region_key)

      rows = []

      # If user has a previous config, show it first (unless already in presets)
      if previous_config && !presets.include?(previous_config.file)
        rows << {
          type: 1, # Action row
          components: [
            {
              type: 2, # Button
              style: 3, # Success (green) - highlight previous choice
              label: "#{previous_config.file} (previous)",
              custom_id: "book_with_config:#{group_name}:#{previous_config.file}"
            }
          ]
        }
      end

      # Regional preset buttons
      rows << {
        type: 1, # Action row
        components: presets.first(5).map do |config|
          style = previous_config&.file == config ? 3 : 1 # Green if previous, blue otherwise
          {
            type: 2, # Button
            style: style,
            label: config,
            custom_id: "book_with_config:#{group_name}:#{config}"
          }
        end
      }

      # "No config" button
      rows << {
        type: 1,
        components: [
          {
            type: 2,
            style: 2, # Secondary (gray)
            label: "No config",
            custom_id: "book_with_config:#{group_name}:__none__"
          }
        ]
      }

      event.respond(
        content: "**Select a config for #{group_name}:**\n\nOr use `/#{Config.command_name} book` with the `config:` option for more choices.",
        components: rows,
        ephemeral: true
      )
    end

    def handle_book_with_config(event, group_name, config_name)
      user = User.find_by(discord_uid: event.user.id.to_s)
      user_info = user ? "#{user.nickname} (#{user.id})" : "unlinked"
      Rails.logger.info "[Discord] book_with_config by #{event.user.username} (#{event.user.id}) -> #{user_info} group=#{group_name} config=#{config_name}"

      # __none__ means explicitly no config (don't use previous)
      # Empty string would fall back to previous config
      config = case config_name
      when "__none__" then "__none__"
      when "", nil then nil
      else config_name
      end

      # Don't pre-acknowledge - let ReserveCommand handle the interaction
      Commands::ReserveCommand.new(event).execute(server_query: group_name, config: config)
    end
  end
end

# Run the bot
if __FILE__ == $PROGRAM_NAME
  ServemeBot::Bot.new.run
end
