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
          return { embed: empty_embed(title), components: [] } if servers.empty?

          # Group by IP address
          by_ip = servers.group_by { |s| s["ip"] }

          # Build and sort server groups
          server_groups = by_ip.map do |_ip, ip_servers|
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

          server_lines = server_groups.map { |s| s[:line] }

          embed = {
            title: title,
            description: server_lines.join("\n"),
            color: SERVEME_COLOR,
            footer: { text: SITE_HOST },
            timestamp: Time.now.iso8601
          }

          # Build Book buttons for available server groups
          available_groups = server_groups.select { |s| s[:available] }.map { |s| s[:name] }
          components = build_book_buttons(available_groups)

          { embed: embed, components: components }
        end

        def format_server_summary(servers)
          available = servers.count { |s| s["available"] }
          total = servers.size

          "#{available}/#{total} servers available"
        end

        private

        def build_book_buttons(group_names)
          return [] if group_names.empty?

          # Limit to 25 buttons (5 rows x 5 buttons)
          group_names = group_names.first(25)

          group_names.each_slice(5).map do |row_groups|
            {
              type: 1, # Action row
              components: row_groups.map do |name|
                # Truncate label if needed (Discord max: 80 chars)
                label = name.length > 75 ? "#{name[0..72]}..." : name
                {
                  type: 2, # Button
                  style: 1, # Primary (blue)
                  label: "Book #{label}",
                  custom_id: "book_group:#{name}"
                }
              end
            }
          end
        end

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
