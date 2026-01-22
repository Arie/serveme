# typed: false
# frozen_string_literal: true

module ServemeBot
  module Commands
    class ServersCommand < BaseCommand
      def execute
        log_command("servers")
        return unless require_linked_account!

        defer_response

        servers = fetch_servers

        result = Formatters::ServerFormatter.format_server_list(
          servers,
          title: "Available Servers"
        )

        edit_response(embeds: [ result[:embed] ], components: result[:components])
      rescue StandardError => e
        Rails.logger.error "ServersCommand error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        edit_response(content: ":x: Failed to fetch servers. Please try again later.")
      end

      private

      def fetch_servers
        starts_at = Time.current
        ends_at = starts_at + 2.hours

        available_servers = ServerForUserFinder.new(current_user, starts_at, ends_at).servers
        all_user_servers = Server.active.where(type: %w[LocalServer SshServer]).reservable_by_user(current_user)

        available_ids = available_servers.pluck(:id)

        all_user_servers.includes(:location).order(:name).map do |server|
          {
            "id" => server.id,
            "name" => server.name,
            "ip" => server.ip,
            "port" => server.port,
            "location" => server.location&.name,
            "flag" => server.location&.flag,
            "available" => available_ids.include?(server.id)
          }
        end.sort_by { |s| [ s["available"] ? 0 : 1, s["name"] ] }
      end
    end
  end
end
