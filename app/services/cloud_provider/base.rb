# typed: strict
# frozen_string_literal: true

require "shellwords"
require "base64"

module CloudProvider
  class Base
    extend T::Sig

    sig { overridable.params(starts_at: T.any(Time, ActiveSupport::TimeWithZone), ends_at: T.any(Time, ActiveSupport::TimeWithZone)).returns(T::Hash[String, T::Hash[Symbol, String]]) }
    def self.locations(starts_at: Time.current, ends_at: 2.hours.from_now)
      # Sorbet can't resolve self::LOCATIONS (each subclass defines its own)
      const_get(:LOCATIONS) # rubocop:disable Sorbet/ConstantsFromStrings
    end

    # Create a VM/container. Returns the provider-assigned ID (string).
    sig { overridable.params(cloud_server: CloudServer).returns(String) }
    def create_server(cloud_server)
      raise NotImplementedError
    end

    # Returns status string: "provisioning", "running", "stopped", "destroyed"
    sig { overridable.params(provider_id: String).returns(String) }
    def server_status(provider_id)
      raise NotImplementedError
    end

    # Returns the IP address once assigned, nil if not yet available
    sig { overridable.params(provider_id: String).returns(T.nilable(String)) }
    def server_ip(provider_id)
      raise NotImplementedError
    end

    # Returns the provisioning phases with estimated durations for the progress bar.
    sig { overridable.returns(T::Array[T::Hash[Symbol, T.untyped]]) }
    def provision_phases
      [
        { key: "creating_vm", label: "Creating VM", icon: "fa-cloud", seconds: 80 },
        { key: "booting", label: "Installing game server", icon: "fa-server", seconds: 100 },
        { key: "configuring", label: "Sending configs", icon: "fa-cog", seconds: 20 },
        { key: "booting_tf2", label: "Starting TF2", icon: "fa-gamepad", seconds: 20 },
        { key: "starting_tf2", label: "Waiting for server", icon: "fa-hourglass-half", seconds: 20 }
      ]
    end

    # Human-readable estimated provision time shown to users.
    sig { overridable.returns(String) }
    def estimated_provision_time
      "a few minutes"
    end

    # Returns estimated provisioning time in seconds for countdown display.
    sig { returns(Integer) }
    def estimated_provision_seconds
      provision_phases.sum { |p| p[:seconds] }
    end

    # Destroy the VM/container. Returns boolean.
    sig { overridable.params(provider_id: String).returns(T::Boolean) }
    def destroy_server(provider_id)
      raise NotImplementedError
    end

    # Returns true if the provider_id is a pending command queue ID (Kamatera).
    sig { overridable.params(_provider_id: T.nilable(String)).returns(T::Boolean) }
    def pending_command?(_provider_id)
      false
    end

    # Poll a pending command to resolve the real server ID. Returns resolved ID or nil.
    sig { overridable.params(_cloud_server: CloudServer).returns(T.nilable(String)) }
    def poll_command(_cloud_server)
      nil
    end

    # Destroy all VMs/containers matching the given label. Returns count destroyed.
    # Used as a safety net to clean up orphaned VMs when provider_id was not saved.
    sig { overridable.params(_label: String).returns(Integer) }
    def destroy_servers_by_label(_label)
      0
    end

    # Create a bare VM with the given name, location, and image. Returns [provider_id, ip].
    # Polls until the VM is running and has an IP assigned.
    sig { overridable.params(name: String, location: String, image: T.nilable(String), user_data: T.nilable(String)).returns([ String, String ]) }
    def create_bare_server(name:, location:, image: nil, user_data: nil)
      raise NotImplementedError
    end

    # Create a temporary VM for snapshotting. Returns [provider_id, ip].
    sig { overridable.params(location: String, setup_script: String).returns([ String, String ]) }
    def create_snapshot_server(location, setup_script)
      raise NotImplementedError
    end

    # Halt/power off a VM. Returns when stopped.
    sig { overridable.params(provider_id: String).void }
    def halt_server(provider_id)
      raise NotImplementedError
    end

    # Create a snapshot from a halted VM. Returns snapshot_id.
    sig { overridable.params(provider_id: String, description: String).returns(String) }
    def create_snapshot(provider_id, description)
      raise NotImplementedError
    end

    # Poll until snapshot is ready.
    sig { overridable.params(snapshot_id: String).void }
    def wait_for_snapshot(snapshot_id)
      raise NotImplementedError
    end

    # Credential key path for storing snapshot ID
    sig { overridable.returns(String) }
    def snapshot_credential_key
      raise NotImplementedError
    end

    # List all VMs at this provider. Returns array of { provider_id:, label:, created_at: }.
    sig { overridable.returns(T::Array[T::Hash[Symbol, T.untyped]]) }
    def list_servers
      []
    end

    # Delete all snapshots except the one to keep. Returns count of deleted snapshots.
    sig { overridable.params(_keep_snapshot_id: String).returns(Integer) }
    def delete_old_snapshots(_keep_snapshot_id)
      0
    end

    sig { params(cloud_server: CloudServer).returns(String) }
    def cloud_server_name(cloud_server)
      region = SITE_HOST == "serveme.tf" ? "eu" : SITE_HOST.split(".").first
      "serveme-#{region}-#{cloud_server.cloud_reservation_id}"
    end

    private

    # Parsed JSON from a successful response; raises with provider context otherwise.
    sig { params(response: Faraday::Response, error_prefix: String).returns(T.untyped) }
    def parse_response(response, error_prefix)
      unless response.success?
        error_detail = extract_api_error(response)
        raise "#{error_prefix} (#{response.status}): #{error_detail || response.body}"
      end
      JSON.parse(response.body)
    end

    sig { params(response: Faraday::Response).returns(T.untyped) }
    def extract_api_error(response)
      data = JSON.parse(response.body)
      error = data["error"]
      error.is_a?(Hash) ? error["message"] : error
    rescue JSON::ParserError
      nil
    end

    sig { params(cloud_server: CloudServer).returns(String) }
    def cloud_init_script(cloud_server)
      image = cloud_init_docker_image(cloud_server)
      env = ContainerEnv.build(
        cloud_server,
        ssh_public_key: Rails.application.credentials.dig(:cloud_servers, :ssh_public_key),
        mode: :vm
      )
      env_lines = ContainerEnv.to_shell_args(env).map { |arg| "  #{arg} \\" }.join("\n")

      <<~CLOUD_INIT
        #!/bin/bash
        #{cloud_init_pre_docker}
        #{cloud_init_seccomp_profile}
        #{cloud_init_docker_pull(cloud_server, image)}
        docker run -d --restart unless-stopped --cap-add=NET_ADMIN --network host \\
          --security-opt seccomp=/etc/docker/seccomp-tf2.json \\
        #{env_lines}
          #{image}
      CLOUD_INIT
    end

    sig { returns(String) }
    def cloud_init_seccomp_profile
      profile_path = Rails.root.join("config/docker/seccomp-tf2.json")
      profile_b64 = Base64.strict_encode64(File.read(profile_path))
      <<~BASH.strip
        install -d -m 0755 /etc/docker
        echo '#{profile_b64}' | base64 -d > /etc/docker/seccomp-tf2.json
        chmod 0644 /etc/docker/seccomp-tf2.json
      BASH
    end

    sig { overridable.returns(String) }
    def cloud_init_pre_docker
      <<~BASH.strip
        if ! command -v docker &>/dev/null; then
          curl -fsSL https://get.docker.com | sh
        fi
      BASH
    end

    sig { overridable.params(_cloud_server: CloudServer).returns(String) }
    def cloud_init_docker_image(_cloud_server)
      "serveme/tf2-cloud-server:latest"
    end

    sig { overridable.params(_cloud_server: CloudServer, image: String).returns(String) }
    def cloud_init_docker_pull(_cloud_server, image)
      <<~BASH.strip
        if ! docker image inspect #{image} >/dev/null 2>&1; then
          docker pull #{image}
        fi
      BASH
    end
  end
end
