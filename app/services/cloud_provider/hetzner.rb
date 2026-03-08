# typed: false
# frozen_string_literal: true

module CloudProvider
  class Hetzner < Base
    API_URL = "https://api.hetzner.cloud/v1"

    LOCATIONS = {
      "fsn1" => { name: "Falkenstein", country: "Germany", region: "EU", flag: "de", server_type: "cpx22" },
      "nbg1" => { name: "Nuremberg", country: "Germany", region: "EU", flag: "de", server_type: "cpx22" },
      "hel1" => { name: "Helsinki", country: "Finland", region: "EU", flag: "fi", server_type: "cpx22" },
      "ash"  => { name: "Ashburn", country: "USA", region: "NA", flag: "us", server_type: "cpx21" },
      "hil"  => { name: "Hillsboro", country: "USA", region: "NA", flag: "us", server_type: "cpx21" }
    }.freeze

    def create_server(cloud_server)
      Rails.logger.info "Hetzner: Creating server for cloud_server #{cloud_server.id}"
      response = connection.post("servers") do |req|
        req.body = {
          name: "serveme-#{cloud_server.id}",
          server_type: server_type_for(cloud_server.cloud_location),
          image: image_id,
          location: cloud_server.cloud_location || default_location,
          ssh_keys: [ ssh_key_name ],
          user_data: cloud_init_script(cloud_server)
        }.to_json
      end
      data = parse_response(response, "Hetzner API error")
      provider_id = data.dig("server", "id").to_s
      Rails.logger.info "Hetzner: Created server #{provider_id} for cloud_server #{cloud_server.id}"
      provider_id
    end

    def server_status(provider_id)
      response = connection.get("servers/#{provider_id}")
      data = parse_response(response, "Hetzner API error")

      hetzner_to_status(data.dig("server", "status"))
    end

    def server_ip(provider_id)
      response = connection.get("servers/#{provider_id}")
      data = parse_response(response, "Hetzner API error")

      data.dig("server", "public_net", "ipv4", "ip")
    end

    # Returns progress percentage (0-100) of the server creation, nil if not available
    def server_progress(provider_id)
      response = connection.get("servers/#{provider_id}/actions")
      return nil unless response.success?

      data = JSON.parse(response.body)
      action = data["actions"]&.find { |a| a["command"] == "create_server" }
      action&.dig("progress")
    end

    def provision_phases
      [
        { key: "creating_vm", label: "Creating VM", icon: "fa-cloud", seconds: 140 },
        { key: "booting", label: "Installing game server", icon: "fa-server", seconds: 15 },
        { key: "configuring", label: "Sending configs", icon: "fa-cog", seconds: 5 },
        { key: "booting_tf2", label: "Starting TF2", icon: "fa-gamepad", seconds: 5 },
        { key: "starting_tf2", label: "Waiting for server", icon: "fa-hourglass-half", seconds: 10 }
      ]
    end

    def estimated_provision_time
      "about 3 minutes"
    end

    def destroy_server(provider_id)
      Rails.logger.info "Hetzner: Destroying server #{provider_id}"
      response = connection.delete("servers/#{provider_id}")
      Rails.logger.info "Hetzner: Destroy server #{provider_id} result: #{response.status}"
      response.success?
    end

    def destroy_servers_by_label(label)
      response = connection.get("servers?name=#{label}")
      return 0 unless response.success?

      data = JSON.parse(response.body)
      servers = data["servers"] || []
      destroyed = 0
      servers.each do |server|
        if destroy_server(server["id"].to_s)
          destroyed += 1
        end
      end
      Rails.logger.info "Hetzner: Destroyed #{destroyed} servers with name #{label}" if destroyed > 0
      destroyed
    end

    def create_snapshot_server(location, setup_script)
      response = connection.post("servers") do |req|
        req.body = {
          name: "serveme-snapshot-#{Time.current.strftime('%Y%m%d%H%M')}",
          server_type: server_type_for(location),
          image: "docker-ce",
          location: location,
          ssh_keys: [ ssh_key_name ],
          user_data: setup_script
        }.to_json
      end
      data = parse_response(response, "Hetzner API error")

      server_id = data.dig("server", "id").to_s

      ip = nil
      60.times do
        sleep 5
        r = connection.get("servers/#{server_id}")
        d = JSON.parse(r.body)
        status = d.dig("server", "status")
        ip = d.dig("server", "public_net", "ipv4", "ip")
        break if status == "running" && ip.present?
      end
      raise "Hetzner VM never became running" unless ip

      [ server_id, ip ]
    end

    def halt_server(provider_id)
      connection.post("servers/#{provider_id}/actions/shutdown")
      30.times do
        sleep 2
        r = connection.get("servers/#{provider_id}")
        d = JSON.parse(r.body)
        return if d.dig("server", "status") == "off"
      end
      raise "Hetzner VM did not power off in time"
    end

    def create_snapshot(provider_id, description)
      response = connection.post("servers/#{provider_id}/actions/create_image") do |req|
        req.body = { type: "snapshot", description: description }.to_json
      end
      data = parse_response(response, "Hetzner snapshot error")

      data.dig("image", "id").to_s
    end

    def wait_for_snapshot(snapshot_id)
      120.times do
        sleep 5
        r = connection.get("images/#{snapshot_id}")
        d = JSON.parse(r.body)
        print "."
        return if d.dig("image", "status") == "available"
      end
      raise "Hetzner snapshot did not become available in time"
    end

    def snapshot_credential_key
      "cloud_servers.hetzner.image_id"
    end

    def list_snapshots
      snapshots = []
      page = 1
      loop do
        response = connection.get("images?type=snapshot&sort=created:desc&page=#{page}&per_page=50")
        data = parse_response(response, "Hetzner API error")
        snapshots.concat(data["images"].select { |i| i["description"].to_s.start_with?("serveme-cloud") })
        break if page >= data.dig("meta", "pagination", "last_page").to_i

        page += 1
      end
      snapshots
    end

    def delete_snapshot(snapshot_id)
      response = connection.delete("images/#{snapshot_id}")
      response.success?
    end

    def delete_old_snapshots(keep_snapshot_id)
      deleted = 0
      list_snapshots.each do |snapshot|
        next if snapshot["id"].to_s == keep_snapshot_id.to_s

        if delete_snapshot(snapshot["id"])
          Rails.logger.info "Hetzner: Deleted old snapshot #{snapshot['id']} (#{snapshot['description']})"
          deleted += 1
        end
      end
      deleted
    end

    private

    def connection
      @connection ||= Faraday.new(url: API_URL) do |f|
        f.headers["Authorization"] = "Bearer #{api_token}"
        f.headers["Content-Type"] = "application/json"
        f.options.timeout = 30
        f.options.open_timeout = 5
      end
    end

    def api_token
      ENV["HCLOUD_TOKEN"] || Rails.application.credentials.dig(:cloud_servers, :hetzner, :api_key)
    end

    def image_id
      latest_snapshot_id || "docker-ce"
    end

    def latest_snapshot_id
      @latest_snapshot_id ||= list_snapshots.first&.dig("id")&.to_s
    end

    def server_type_for(location)
      LOCATIONS.dig(location, :server_type) || "cpx22"
    end

    def default_location
      "fsn1"
    end

    def ssh_key_name
      Rails.application.credentials.dig(:cloud_servers, :hetzner, :ssh_key_name) || "serveme-cloud"
    end

    def hetzner_to_status(hetzner_status)
      case hetzner_status
      when "initializing", "starting" then "provisioning"
      when "running" then "running"
      when "stopping", "off", "deleting" then "stopped"
      else "provisioning"
      end
    end
  end
end
