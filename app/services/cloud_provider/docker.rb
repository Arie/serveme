# typed: false
# frozen_string_literal: true

require "open3"

module CloudProvider
  class Docker < Base
    LOCATIONS = T.let({
      "local" => { name: "Local", country: "LAN", region: "LAN", flag: "eu" }
    }.freeze, T::Hash[String, T::Hash[Symbol, String]])
    def create_server(cloud_server)
      Rails.logger.info "Docker: Creating container for cloud_server #{cloud_server.id}"
      callback_host = ENV.fetch("CALLBACK_HOST", "host.docker.internal:3000")
      callback_url = "http://#{callback_host}/api/cloud_servers/#{cloud_server.id}/ready"
      callback_token = cloud_server.cloud_callback_token
      public_key = cloud_server.cloud_ssh_public_key
      container_name = "cloud-#{cloud_server.id}"

      game_port = cloud_server.port.to_i
      tv_port = game_port + 5
      server_index = (game_port - 27015) / 10
      ssh_port = 22000 + server_index
      client_port = 40001 + server_index
      steam_port = 30001 + server_index

      cmd = %W[
        docker run -d --net=host
        --name #{container_name}
        -e CALLBACK_URL=#{callback_url}
        -e CALLBACK_TOKEN=#{callback_token}
        -e SSH_AUTHORIZED_KEYS=#{public_key}
        -e RCON_PASSWORD=#{cloud_server.rcon}
        -e PORT=#{game_port}
        -e TV_PORT=#{tv_port}
        -e SSH_PORT=#{ssh_port}
        -e CLIENT_PORT=#{client_port}
        -e STEAM_PORT=#{steam_port}
        -e ENABLE_FAKEIP=1
        -e EXPECTED_TF2_VERSION=#{Server.latest_version}
        tf2-cloud-server
      ]
      success = system(*cmd)
      raise "Docker container failed to start: #{container_name}" unless success
      Rails.logger.info "Docker: Created container #{container_name}"
      container_name
    end

    def estimated_provision_time
      "less than a minute"
    end

    def server_status(provider_id)
      output, status = Open3.capture2("docker", "inspect", "-f", "{{.State.Status}}", provider_id)
      output = output.strip
      return "provisioning" unless status.success?

      case output
      when "running" then "running"
      when "created", "restarting" then "provisioning"
      when "exited", "dead", "removing" then "stopped"
      else "provisioning"
      end
    end

    def server_ip(_provider_id)
      @server_ip ||= ENV.fetch("DOCKER_HOST_IP") { detect_host_ip }
    end

    def destroy_server(provider_id)
      Rails.logger.info "Docker: Destroying container #{provider_id}"
      result = system("docker", "rm", "-f", provider_id) || false
      Rails.logger.info "Docker: Destroy container #{provider_id} result: #{result}"
      result
    end

    private

    def detect_host_ip
      output, = Open3.capture2("hostname", "-I")
      output.split.first || "127.0.0.1"
    end
  end
end
