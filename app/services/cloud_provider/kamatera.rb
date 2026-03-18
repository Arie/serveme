# typed: false
# frozen_string_literal: true

module CloudProvider
  class Kamatera < Base
    API_URL = "https://console.kamatera.com/service"

    LOCATIONS = {
      # EU
      "EU"    => { name: "Amsterdam", country: "Netherlands", region: "EU", flag: "nl" },
      "EU-LO" => { name: "London", country: "UK", region: "EU", flag: "uk" },
      "EU-FR" => { name: "Frankfurt", country: "Germany", region: "EU", flag: "de" },
      "EU-ML" => { name: "Milan", country: "Italy", region: "EU", flag: "it" },
      "EU-MD" => { name: "Madrid", country: "Spain", region: "EU", flag: "es" },
      "EU-ST" => { name: "Stockholm", country: "Sweden", region: "EU", flag: "se" },
      "IL-TA" => { name: "Tel Aviv", country: "Israel", region: "EU", flag: "il" },
      "IL-PT" => { name: "Petah Tikva", country: "Israel", region: "EU", flag: "il" },
      "IL-HA" => { name: "Haifa", country: "Israel", region: "EU", flag: "il" },
      "IL"    => { name: "Rosh Haain", country: "Israel", region: "EU", flag: "il" },
      "IL-RH" => { name: "Rosh Haain 2", country: "Israel", region: "EU", flag: "il" },
      # NA
      "US-NY2" => { name: "New York", country: "USA", region: "NA", flag: "us" },
      "US-SC"  => { name: "Santa Clara", country: "USA", region: "NA", flag: "us" },
      "US-TX"  => { name: "Dallas", country: "USA", region: "NA", flag: "us" },
      "US-CH"  => { name: "Chicago", country: "USA", region: "NA", flag: "us" },
      "US-MI"  => { name: "Miami", country: "USA", region: "NA", flag: "us" },
      "US-AT"  => { name: "Atlanta", country: "USA", region: "NA", flag: "us" },
      "US-SE"  => { name: "Seattle", country: "USA", region: "NA", flag: "us" },
      "US-LA"  => { name: "Los Angeles", country: "USA", region: "NA", flag: "us" },
      "CA-TR"  => { name: "Toronto", country: "Canada", region: "NA", flag: "ca" },
      # AU
      "AU-SY" => { name: "Sydney", country: "Australia", region: "AU", flag: "au" },
      # SEA
      "AS"    => { name: "Hong Kong", country: "Hong Kong", region: "SEA", flag: "hk" },
      "AS-SG" => { name: "Singapore", country: "Singapore", region: "SEA", flag: "sg" },
      "AS-TY" => { name: "Tokyo", country: "Japan", region: "SEA", flag: "jp" }
    }.freeze

    def create_server(cloud_server)
      Rails.logger.info "Kamatera: Creating server for cloud_server #{cloud_server.id}"
      location = cloud_server.cloud_location || default_location

      cloud_server.update!(cloud_ssh_port: 22)
      params = {
        name: "serveme-#{cloud_server.id}",
        datacenter: location,
        cpu: cpu_type,
        ram: ram_mb,
        disk_size_0: disk_size,
        disk_src_0: image_id(location),
        billing: "hourly",
        traffic: traffic_package,
        network_name_0: "wan",
        power: 1,
        password: server_password,
        selectedSSHKeyValue: ssh_public_key,
        script: cloud_init_script(cloud_server)
      }
      response = connection.post("server") do |req|
        req.headers["Content-Type"] = "application/x-www-form-urlencoded"
        req.body = URI.encode_www_form(params)
      end
      data = parse_response(response, "Kamatera API error")

      # Kamatera returns an array with command IDs - we need to poll for the server
      command_ids = data.is_a?(Array) ? data : [ data ]
      Rails.logger.info "Kamatera: Create command IDs #{command_ids} for cloud_server #{cloud_server.id}"

      # Poll command status to get the server ID
      server_id = nil
      120.times do
        sleep 5
        cmd_response = connection.get("queue/#{command_ids.first}")
        next unless cmd_response.success?

        cmd_data = JSON.parse(cmd_response.body)
        status = cmd_data["status"] if cmd_data.is_a?(Hash)
        if status == "complete"
          # The server name is what we use as provider_id for Kamatera
          server_id = "serveme-#{cloud_server.id}"
          break
        elsif status == "error"
          raise "Kamatera server creation failed: #{cmd_data['log']}"
        end
      end
      raise "Kamatera server creation timed out" unless server_id

      Rails.logger.info "Kamatera: Created server #{server_id} for cloud_server #{cloud_server.id}"
      server_id
    end

    def server_status(provider_id)
      response = connection.get("server/#{provider_id}")
      return "provisioning" unless response.success?

      data = JSON.parse(response.body)
      kamatera_to_status(data["power"])
    end

    def server_ip(provider_id)
      response = connection.get("server/#{provider_id}")
      return nil unless response.success?

      data = JSON.parse(response.body)
      networks = data["networks"] || []
      wan = networks.find { |n| n["network"]&.start_with?("wan") }
      wan&.dig("ips")&.first
    end

    def provision_phases
      [
        { key: "creating_vm", label: "Creating VM", icon: "fa-cloud", seconds: 120 },
        { key: "booting", label: "Installing game server", icon: "fa-server", seconds: 60 },
        { key: "configuring", label: "Sending configs", icon: "fa-cog", seconds: 15 },
        { key: "booting_tf2", label: "Starting TF2", icon: "fa-gamepad", seconds: 15 },
        { key: "starting_tf2", label: "Waiting for server", icon: "fa-hourglass-half", seconds: 15 }
      ]
    end

    def estimated_provision_time
      "about 4 minutes"
    end

    def destroy_server(provider_id)
      Rails.logger.info "Kamatera: Destroying server #{provider_id}"
      response = connection.delete("server/#{provider_id}/terminate") do |req|
        req.headers["Content-Type"] = "application/x-www-form-urlencoded"
        req.body = URI.encode_www_form(confirm: "1", force: "1")
      end
      Rails.logger.info "Kamatera: Destroy server #{provider_id} result: #{response.status}"
      response.success?
    end

    def destroy_servers_by_label(label)
      response = connection.get("servers")
      return 0 unless response.success?

      data = JSON.parse(response.body)
      servers = data.is_a?(Array) ? data : []
      destroyed = 0
      servers.each do |server|
        if server["name"] == label
          if destroy_server(server["name"])
            destroyed += 1
          end
        end
      end
      Rails.logger.info "Kamatera: Destroyed #{destroyed} servers with name #{label}" if destroyed > 0
      destroyed
    end

    def create_snapshot_server(_location, _setup_script)
      raise NotImplementedError, "Kamatera snapshot creation not yet implemented"
    end

    def halt_server(_provider_id)
      raise NotImplementedError, "Kamatera halt not yet implemented"
    end

    def create_snapshot(_provider_id, _description)
      raise NotImplementedError, "Kamatera snapshots not yet implemented"
    end

    def wait_for_snapshot(_snapshot_id)
      raise NotImplementedError, "Kamatera snapshots not yet implemented"
    end

    def snapshot_credential_key
      "cloud_servers.kamatera.snapshot_id"
    end

    private

    def connection
      @connection ||= Faraday.new(url: API_URL) do |f|
        f.headers["Content-Type"] = "application/json"
        f.headers["Authorization"] = "Bearer #{auth_token}"
        f.options.timeout = 30
        f.options.open_timeout = 5
      end
    end

    def auth_token
      @auth_token ||= begin
        conn = Faraday.new(url: API_URL) do |f|
          f.headers["Content-Type"] = "application/json"
          f.options.timeout = 10
          f.options.open_timeout = 5
        end
        response = conn.post("authenticate") do |req|
          req.body = { clientId: client_id, secret: client_secret }.to_json
        end
        raise "Kamatera authentication failed (#{response.status})" unless response.success?

        JSON.parse(response.body)["authentication"]
      end
    end

    def client_id
      ENV["KAMATERA_CLIENT_ID"] || Rails.application.credentials.dig(:cloud_servers, :kamatera, :access_key)
    end

    def client_secret
      ENV["KAMATERA_SECRET"] || Rails.application.credentials.dig(:cloud_servers, :kamatera, :secret_key)
    end

    def ssh_public_key
      Rails.application.credentials.dig(:cloud_servers, :ssh_public_key)
    end

    UBUNTU_24_IMAGE_UUID = "6000C29549da189eaef6ea8a31001a34"

    def image_id(datacenter)
      "#{datacenter}:#{UBUNTU_24_IMAGE_UUID}"
    end

    def server_password
      "Sv#{SecureRandom.hex(8)}"
    end

    def cpu_type
      "2B" # 2 dedicated CPU cores
    end

    def ram_mb
      2048
    end

    def disk_size
      20
    end

    def traffic_package
      "t5000"
    end

    def default_location
      "AS"
    end

    def kamatera_to_status(power)
      case power
      when "on" then "running"
      when "off" then "stopped"
      else "provisioning"
      end
    end
  end
end
