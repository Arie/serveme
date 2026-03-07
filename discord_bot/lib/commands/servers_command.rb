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

        servers = all_user_servers.includes(:location).order(:name).map do |server|
          {
            "id" => server.id,
            "name" => server.name,
            "ip" => server.ip,
            "port" => server.port,
            "location" => server.location&.name,
            "flag" => server.location&.flag,
            "available" => available_ids.include?(server.id)
          }
        end

        # Include Docker hosts as on-demand cloud servers
        DockerHost.active.includes(:location).each do |host|
          available_slots = (host.max_containers || 4) - host.container_count_during(starts_at, ends_at)
          servers << {
            "id" => host.virtual_server_id,
            "name" => host.city,
            "ip" => host.ip,
            "location" => host.location&.name,
            "flag" => host.location&.flag,
            "available" => available_slots > 0,
            "cloud" => true,
            "docker_host_id" => host.id,
            "available_slots" => [ available_slots, 0 ].max,
            "total_slots" => host.max_containers || 4
          }
        end

        servers.sort_by { |s| [ s["available"] ? 0 : 1, s["name"] ] }
      end
    end
  end
end
