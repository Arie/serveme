# typed: false
# frozen_string_literal: true

require "open3"

module CloudProvider
  class Docker < Base
    LOCATIONS = T.let({}.freeze, T::Hash[String, T::Hash[Symbol, String]])
    def create_server(cloud_server)
      Rails.logger.info "Docker: Creating container for cloud_server #{cloud_server.id}"
      callback_host = ENV.fetch("CALLBACK_HOST", "host.docker.internal:3000")
      callback_url = "http://#{callback_host}/api/cloud_servers/#{cloud_server.id}/ready"
      callback_token = cloud_server.cloud_callback_token
      public_key = File.read(Rails.root.join("tmp", "cloud_ssh_key.pub")).strip
      container_name = "cloud-#{cloud_server.id}"

      cmd = %W[
        docker run -d --cap-add=NET_ADMIN
        --name #{container_name}
        -p 27015:27015/udp -p 27015:27015/tcp
        -p 27020:27020/udp -p 2222:22
        --add-host host.docker.internal:host-gateway
        -e CALLBACK_URL=#{callback_url}
        -e CALLBACK_TOKEN=#{callback_token}
        -e SSH_AUTHORIZED_KEYS=#{public_key}
        -e RCON_PASSWORD=#{cloud_server.rcon}
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

    def server_ip(provider_id)
      "127.0.0.1"
    end

    def destroy_server(provider_id)
      Rails.logger.info "Docker: Destroying container #{provider_id}"
      result = system("docker", "rm", "-f", provider_id) || false
      Rails.logger.info "Docker: Destroy container #{provider_id} result: #{result}"
      result
    end
  end
end
