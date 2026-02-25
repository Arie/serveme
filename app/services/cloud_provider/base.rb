# typed: false
# frozen_string_literal: true

module CloudProvider
  class Base
    def self.locations
      self::LOCATIONS
    end
    # Create a VM/container. Returns the provider-assigned ID (string).
    def create_server(cloud_server)
      raise NotImplementedError
    end

    # Returns status string: "provisioning", "running", "stopped", "destroyed"
    def server_status(provider_id)
      raise NotImplementedError
    end

    # Returns the IP address once assigned, nil if not yet available
    def server_ip(provider_id)
      raise NotImplementedError
    end

    # Returns the provisioning phases with estimated durations for the progress bar.
    def provision_phases
      [
        { key: "creating_vm", label: "Creating VM", icon: "fa-cloud", seconds: 80 },
        { key: "booting", label: "Installing game server", icon: "fa-server", seconds: 100 },
        { key: "configuring", label: "Applying config", icon: "fa-cog", seconds: 60 }
      ]
    end

    # Human-readable estimated provision time shown to users.
    def estimated_provision_time
      "a few minutes"
    end

    # Returns estimated provisioning time in seconds for countdown display.
    def estimated_provision_seconds
      provision_phases.sum { |p| p[:seconds] }
    end

    # Destroy the VM/container. Returns boolean.
    def destroy_server(provider_id)
      raise NotImplementedError
    end

    # Create a temporary VM for snapshotting. Returns [provider_id, ip].
    def create_snapshot_server(location, setup_script)
      raise NotImplementedError
    end

    # Halt/power off a VM. Returns when stopped.
    def halt_server(provider_id)
      raise NotImplementedError
    end

    # Create a snapshot from a halted VM. Returns snapshot_id.
    def create_snapshot(provider_id, description)
      raise NotImplementedError
    end

    # Poll until snapshot is ready.
    def wait_for_snapshot(snapshot_id)
      raise NotImplementedError
    end

    # Credential key path for storing snapshot ID
    def snapshot_credential_key
      raise NotImplementedError
    end

    # Delete all snapshots except the one to keep. Returns count of deleted snapshots.
    def delete_old_snapshots(keep_snapshot_id)
      0
    end

    private

    def parse_response(response, error_prefix)
      unless response.success?
        error_detail = extract_api_error(response)
        raise "#{error_prefix} (#{response.status}): #{error_detail || response.body}"
      end
      JSON.parse(response.body)
    end

    def extract_api_error(response)
      data = JSON.parse(response.body)
      error = data["error"]
      error.is_a?(Hash) ? error["message"] : error
    rescue JSON::ParserError
      nil
    end

    def cloud_init_script(cloud_server)
      callback_token = cloud_server.cloud_callback_token
      ssh_public_key = Rails.application.credentials.dig(:cloud_servers, :ssh_public_key)
      image = cloud_init_docker_image(cloud_server)

      <<~CLOUD_INIT
        #!/bin/bash
        #{cloud_init_pre_docker}
        #{cloud_init_docker_pull(cloud_server, image)}
        docker run -d --cap-add=NET_ADMIN --network host \
          -e CALLBACK_URL=#{callback_url(cloud_server)} \
          -e CALLBACK_TOKEN=#{callback_token} \
          -e SSH_AUTHORIZED_KEYS="#{ssh_public_key}" \
          -e RCON_PASSWORD=#{cloud_server.rcon} \
          -e SSH_PORT=2222 \
          -e ENABLE_FAKEIP=1 \
          #{image}
      CLOUD_INIT
    end

    def cloud_init_pre_docker
      <<~BASH.strip
        if ! command -v docker &>/dev/null; then
          curl -fsSL https://get.docker.com | sh
        fi
      BASH
    end

    def cloud_init_docker_image(_cloud_server)
      "serveme/tf2-cloud-server:latest"
    end

    def cloud_init_docker_pull(_cloud_server, image)
      <<~BASH.strip
        if ! docker image inspect #{image} >/dev/null 2>&1; then
          docker pull #{image}
        fi
      BASH
    end

    # Build the callback URL for the cloud-init script.
    # In production uses SITE_HOST with https.
    # Set CLOUD_CALLBACK_HOST env var to override for local testing
    # (e.g. CLOUD_CALLBACK_HOST=ariekanarie.nl:3000).
    def callback_url(cloud_server)
      if ENV["CLOUD_CALLBACK_HOST"]
        "http://#{ENV['CLOUD_CALLBACK_HOST']}/api/cloud_servers/#{cloud_server.id}/ready"
      else
        "https://#{SITE_HOST}/api/cloud_servers/#{cloud_server.id}/ready"
      end
    end
  end
end
