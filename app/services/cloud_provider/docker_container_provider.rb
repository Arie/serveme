# typed: false
# frozen_string_literal: true

require "shellwords"

module CloudProvider
  # Shared logic for providers that drive `docker run` directly on an
  # existing host (rather than provisioning a fresh VM). Subclasses
  # supply the executor (local exec vs SSH).
  class DockerContainerProvider < Base
    def container_name(cloud_server)
      "res-#{cloud_server.cloud_reservation_id}-cloud-#{cloud_server.id}"
    end

    def docker_image
      "tf2-cloud-server"
    end

    # Argv for local exec: each element is one argv slot, no shell escaping.
    def docker_run_argv(cloud_server)
      [
        "docker", "run", "-d", "--net=host",
        "--security-opt", "seccomp=/etc/docker/seccomp-tf2.json",
        "--name", container_name(cloud_server),
        *ContainerEnv.to_argv_pairs(env_hash(cloud_server)),
        docker_image
      ]
    end

    # Single shell string for SSH exec. Values are shell-escaped; flag
    # names stay literal so SigNoz greps keep working.
    def docker_run_command(cloud_server)
      parts = [
        "docker run -d --net=host",
        "--security-opt seccomp=/etc/docker/seccomp-tf2.json",
        "--name #{Shellwords.shellescape(container_name(cloud_server))}",
        *ContainerEnv.to_shell_args(env_hash(cloud_server)),
        docker_image
      ]
      parts.join(" ")
    end

    def parse_docker_state(raw)
      case raw.to_s.strip
      when "running" then "running"
      when "created", "restarting" then "provisioning"
      when "exited", "dead", "removing" then "stopped"
      else "provisioning"
      end
    end

    private

    def env_hash(cloud_server)
      ContainerEnv.build(
        cloud_server,
        ssh_public_key: cloud_server.cloud_ssh_public_key,
        mode: :multi
      )
    end
  end
end
