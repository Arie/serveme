# typed: false
# frozen_string_literal: true

require "open3"

module CloudProvider
  class Docker < DockerContainerProvider
    LOCATIONS = T.let({
      "local" => { name: "Local", country: "LAN", region: "LAN", flag: "eu" }
    }.freeze, T::Hash[String, T::Hash[Symbol, String]])

    def create_server(cloud_server)
      Rails.logger.info "Docker: Creating container for cloud_server #{cloud_server.id}"
      name = container_name(cloud_server)
      success = system(*docker_run_argv(cloud_server))
      raise "Docker container failed to start: #{name}" unless success

      Rails.logger.info "Docker: Created container #{name}"
      name
    end

    def estimated_provision_time
      "less than a minute"
    end

    def server_status(provider_id)
      output, status = Open3.capture2("docker", "inspect", "-f", "{{.State.Status}}", provider_id)
      return "provisioning" unless status.success?

      parse_docker_state(output)
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
