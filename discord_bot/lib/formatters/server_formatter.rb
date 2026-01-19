# typed: false
# frozen_string_literal: true

module ServemeBot
  module Formatters
    class ServerFormatter
      SERVEME_COLOR = 0x5865F2 # Discord blurple
      AVAILABLE_COLOR = 0x57F287 # Green
      BUSY_COLOR = 0xED4245 # Red

      class << self
        def format_server_list(servers, title: "Available Servers")
          return empty_embed(title) if servers.empty?

          # Group by IP address
          by_ip = servers.group_by { |s| s["ip"] }

          # Build and sort lines
          server_lines = by_ip.map do |_ip, ip_servers|
            flag_code = ip_servers.first&.dig("flag")
            flag = Helpers::FlagHelper.to_discord_emoji(flag_code)
            # Use server name, strip #N suffix to get base name (preserve qualifiers like "(Anti-DDoS)")
            server_name = ip_servers.first&.dig("name") || "Unknown"
            base_name = server_name.sub(/\s*#\d+/, "").strip
            available_count = ip_servers.count { |s| s["available"] }
            total_count = ip_servers.size

            line = if available_count > 0
              "#{flag} **#{base_name}** - #{available_count}/#{total_count} available"
            else
              "#{flag} ~~#{base_name}~~ - 0/#{total_count} available"
            end

            { line: line, available: available_count > 0, name: base_name }
          end.sort_by { |s| [ s[:available] ? 0 : 1, s[:name] ] }
             .map { |s| s[:line] }

          {
            title: title,
            description: server_lines.join("\n"),
            color: SERVEME_COLOR,
            footer: { text: SITE_HOST },
            timestamp: Time.now.iso8601
          }
        end

        def format_server_summary(servers)
          available = servers.count { |s| s["available"] }
          total = servers.size

          "#{available}/#{total} servers available"
        end

        private

        def empty_embed(title)
          {
            title: title,
            description: "No servers found.",
            color: SERVEME_COLOR
          }
        end

        def format_time(time_string)
          return "?" unless time_string

          time = Time.parse(time_string)
          time.strftime("%H:%M")
        rescue ArgumentError
          "?"
        end
      end
    end
  end
end
