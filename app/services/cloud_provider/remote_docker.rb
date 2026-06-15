# typed: strict
# frozen_string_literal: true

require "net/ssh"
require "shellwords"

module CloudProvider
  class RemoteDocker < DockerContainerProvider
    sig { override.params(starts_at: T.any(Time, ActiveSupport::TimeWithZone), ends_at: T.any(Time, ActiveSupport::TimeWithZone)).returns(T::Hash[String, T::Hash[Symbol, String]]) }
    def self.locations(starts_at: Time.current, ends_at: 2.hours.from_now)
      return {} if DockerImageReadiness.stale?

      DockerHost.active.ordered.each_with_object({}) do |host, hash|
        next if host.full_during?(starts_at, ends_at)

        location = T.must(host.location)
        hash[host.id.to_s] = {
          name: host.city,
          hostname: host.hostname,
          country: location.name,
          flag: location.flag
        }
      end
    end

    sig { override.returns(String) }
    def docker_image
      "serveme/tf2-cloud-server:latest"
    end

    sig { override.params(cloud_server: CloudServer).returns(String) }
    def create_server(cloud_server)
      Rails.logger.info "RemoteDocker: Creating container for cloud_server #{cloud_server.id}"
      docker_host = DockerHost.find(T.must(cloud_server.cloud_location))
      name = container_name(cloud_server)
      run_cmd = docker_run_command(cloud_server)

      ssh_to_host(docker_host) do |ssh|
        ssh.exec!("timeout 600 docker pull #{docker_image}")
        output = ssh.exec!(run_cmd)
        raise "RemoteDocker container failed to start on #{docker_host.ip}: #{output}" if output.nil? || output.strip.empty?

        Rails.logger.info "RemoteDocker: Created container #{name} on #{docker_host.ip}"
      end

      "#{docker_host.id}:#{name}"
    end

    sig { override.returns(String) }
    def estimated_provision_time
      "about 1 minute"
    end

    sig { override.returns(T::Array[T::Hash[Symbol, T.untyped]]) }
    def provision_phases
      [
        { key: "creating_vm", label: "Starting container", icon: "fa-server", seconds: 5 },
        { key: "booting", label: "Waiting for SSH", icon: "fa-terminal", seconds: 5 },
        { key: "configuring", label: "Sending configs", icon: "fa-cog", seconds: 10 },
        { key: "booting_tf2", label: "Starting TF2", icon: "fa-gamepad", seconds: 10 },
        { key: "starting_tf2", label: "Waiting for server", icon: "fa-hourglass-half", seconds: 20 }
      ]
    end

    sig { override.params(provider_id: String).returns(String) }
    def server_status(provider_id)
      docker_host_id, name = provider_id.split(":", 2)
      docker_host = DockerHost.find(T.must(docker_host_id))

      output = ssh_to_host(docker_host) do |ssh|
        ssh.exec!("docker inspect -f '{{.State.Status}}' #{Shellwords.shellescape(T.must(name))}")
      end

      return "provisioning" if output.nil?

      parse_docker_state(output)
    end

    sig { override.params(provider_id: String).returns(T.nilable(String)) }
    def server_ip(provider_id)
      docker_host_id, = provider_id.split(":", 2)
      DockerHost.find(T.must(docker_host_id)).ip
    end

    sig { override.params(provider_id: String).returns(T::Boolean) }
    def destroy_server(provider_id)
      docker_host_id, name = provider_id.split(":", 2)
      docker_host = DockerHost.find(T.must(docker_host_id))

      Rails.logger.info "RemoteDocker: Destroying container #{name} on #{docker_host.ip}"
      output = ssh_to_host(docker_host) do |ssh|
        ssh.exec!("docker rm -f #{Shellwords.shellescape(T.must(name))}")
      end
      result = output.present?
      Rails.logger.info "RemoteDocker: Destroy container #{name} result: #{result}"
      result
    end

    private

    sig { params(docker_host: DockerHost, block: T.proc.params(ssh: T.untyped).returns(T.untyped)).returns(T.untyped) }
    def ssh_to_host(docker_host, &block)
      opts = { timeout: 5, keepalive: true, keepalive_interval: 5, keepalive_maxcount: 2, bind_address: "0.0.0.0", port: docker_host.ssh_port }
      user = docker_host.ssh_user

      if docker_host.provider?
        key_data = Rails.application.credentials.dig(:cloud_servers, :ssh_private_key)
        if key_data.present?
          opts[:key_data] = [ key_data ]
          opts[:keys_only] = true
        end
        opts[:verify_host_key] = :never
      end

      Net::SSH.start(docker_host.hostname, user, **opts, &block)
    end
  end
end
