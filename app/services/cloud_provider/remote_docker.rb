# typed: false
# frozen_string_literal: true

require "net/ssh"
require "shellwords"

module CloudProvider
  class RemoteDocker < Base
    def self.locations(starts_at: Time.current, ends_at: 2.hours.from_now)
      DockerHost.active.includes(:location).each_with_object({}) do |host, hash|
        next if host.full_during?(starts_at, ends_at)

        hash[host.id.to_s] = {
          name: host.city,
          hostname: host.ip,
          country: host.location.name,
          flag: host.location.flag
        }
      end
    end

    def create_server(cloud_server)
      Rails.logger.info "RemoteDocker: Creating container for cloud_server #{cloud_server.id}"
      docker_host = DockerHost.find(cloud_server.cloud_location)
      public_key = cloud_server.cloud_ssh_public_key
      container_name = "cloud-#{cloud_server.id}"

      game_port = cloud_server.port.to_i
      tv_port = game_port + 5
      port_offset = (game_port - 27015) / 10
      ssh_port = 22000 + port_offset
      client_port = 40001 + port_offset
      steam_port = 30001 + port_offset

      docker_run_cmd = [
        "docker run -d --net=host",
        "--name #{container_name}",
        "-e CALLBACK_URL=#{callback_url(cloud_server)}",
        "-e CALLBACK_TOKEN=#{cloud_server.cloud_callback_token}",
        "-e SSH_AUTHORIZED_KEYS=#{Shellwords.shellescape(public_key)}",
        "-e RCON_PASSWORD=#{Shellwords.shellescape(cloud_server.rcon)}",
        "-e PORT=#{game_port}",
        "-e TV_PORT=#{tv_port}",
        "-e SSH_PORT=#{ssh_port}",
        "-e CLIENT_PORT=#{client_port}",
        "-e STEAM_PORT=#{steam_port}",
        "-e ENABLE_FAKEIP=1",
        "-e EXPECTED_TF2_VERSION=#{Server.latest_version}",
        "serveme/tf2-cloud-server:latest"
      ].join(" ")

      ssh_to_host(docker_host) do |ssh|
        ssh.exec!("timeout 600 docker pull serveme/tf2-cloud-server:latest")
        output = ssh.exec!(docker_run_cmd)
        raise "RemoteDocker container failed to start on #{docker_host.ip}: #{output}" if output.nil? || output.strip.empty?
        Rails.logger.info "RemoteDocker: Created container #{container_name} on #{docker_host.ip}"
      end

      "#{docker_host.id}:#{container_name}"
    end

    def estimated_provision_time
      "about 1 minute"
    end

    def provision_phases
      [
        { key: "creating_vm", label: "Starting container", icon: "fa-server", seconds: 5 },
        { key: "booting", label: "Waiting for SSH", icon: "fa-terminal", seconds: 5 },
        { key: "configuring", label: "Sending configs", icon: "fa-cog", seconds: 10 },
        { key: "booting_tf2", label: "Starting TF2", icon: "fa-gamepad", seconds: 10 },
        { key: "starting_tf2", label: "Waiting for server", icon: "fa-hourglass-half", seconds: 20 }
      ]
    end

    def server_status(provider_id)
      docker_host_id, container_name = provider_id.split(":", 2)
      docker_host = DockerHost.find(docker_host_id)

      output = ssh_to_host(docker_host) do |ssh|
        ssh.exec!("docker inspect -f '{{.State.Status}}' #{container_name}")
      end

      return "provisioning" if output.nil?

      case output.strip
      when "running" then "running"
      when "created", "restarting" then "provisioning"
      when "exited", "dead", "removing" then "stopped"
      else "provisioning"
      end
    end

    def server_ip(provider_id)
      docker_host_id, = provider_id.split(":", 2)
      DockerHost.find(docker_host_id).ip
    end

    def destroy_server(provider_id)
      docker_host_id, container_name = provider_id.split(":", 2)
      docker_host = DockerHost.find(docker_host_id)

      Rails.logger.info "RemoteDocker: Destroying container #{container_name} on #{docker_host.ip}"
      output = ssh_to_host(docker_host) do |ssh|
        ssh.exec!("docker rm -f #{container_name}")
      end
      result = output.present?
      Rails.logger.info "RemoteDocker: Destroy container #{container_name} result: #{result}"
      result
    end

    private

    def ssh_to_host(docker_host, &block)
      Net::SSH.start(docker_host.ip, nil, timeout: 5, keepalive: true, keepalive_interval: 5, keepalive_maxcount: 2, &block)
    end
  end
end
