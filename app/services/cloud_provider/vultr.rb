# typed: false
# frozen_string_literal: true

module CloudProvider
  class Vultr < Base
    API_URL = "https://api.vultr.com/v2"

    LOCATIONS = {
      # EU
      "ams" => { name: "Amsterdam", country: "Netherlands", region: "EU", flag: "nl" },
      "fra" => { name: "Frankfurt", country: "Germany", region: "EU", flag: "de" },
      "lhr" => { name: "London", country: "UK", region: "EU", flag: "uk" },
      "cdg" => { name: "Paris", country: "France", region: "EU", flag: "fr" },
      "mad" => { name: "Madrid", country: "Spain", region: "EU", flag: "es" },
      "sto" => { name: "Stockholm", country: "Sweden", region: "EU", flag: "se" },
      "waw" => { name: "Warsaw", country: "Poland", region: "EU", flag: "pl" },
      "man" => { name: "Manchester", country: "UK", region: "EU", flag: "uk" },
      # NA
      "ewr" => { name: "New Jersey", country: "USA", region: "NA", flag: "us" },
      "ord" => { name: "Chicago", country: "USA", region: "NA", flag: "us" },
      "dfw" => { name: "Dallas", country: "USA", region: "NA", flag: "us" },
      "lax" => { name: "Los Angeles", country: "USA", region: "NA", flag: "us" },
      "sea" => { name: "Seattle", country: "USA", region: "NA", flag: "us" },
      "sjc" => { name: "Silicon Valley", country: "USA", region: "NA", flag: "us" },
      "mia" => { name: "Miami", country: "USA", region: "NA", flag: "us" },
      "atl" => { name: "Atlanta", country: "USA", region: "NA", flag: "us" },
      "hnl" => { name: "Honolulu", country: "USA", region: "NA", flag: "us" },
      "yto" => { name: "Toronto", country: "Canada", region: "NA", flag: "ca" },
      "mex" => { name: "Mexico City", country: "Mexico", region: "NA", flag: "mx" },
      # AU
      "syd" => { name: "Sydney", country: "Australia", region: "AU", flag: "au" },
      "mel" => { name: "Melbourne", country: "Australia", region: "AU", flag: "au" },
      # SEA
      "sgp" => { name: "Singapore", country: "Singapore", region: "SEA", flag: "sg" },
      "nrt" => { name: "Tokyo", country: "Japan", region: "SEA", flag: "jp" },
      "itm" => { name: "Osaka", country: "Japan", region: "SEA", flag: "jp" },
      "icn" => { name: "Seoul", country: "South Korea", region: "SEA", flag: "kr" }
    }.freeze

    def create_server(cloud_server)
      Rails.logger.info "Vultr: Creating server for cloud_server #{cloud_server.id}"
      body = {
        label: "serveme-#{cloud_server.id}",
        plan: plan,
        region: cloud_server.cloud_location || default_region,
        sshkey_id: [ ssh_key_id ],
        user_data: Base64.strict_encode64(cloud_init_script(cloud_server))
      }
      if snapshot_id
        body[:snapshot_id] = snapshot_id
      else
        body[:image_id] = marketplace_image_id
      end

      response = connection.post("instances") do |req|
        req.body = body.to_json
      end
      data = parse_response(response, "Vultr API error")
      provider_id = data.dig("instance", "id")
      Rails.logger.info "Vultr: Created server #{provider_id} for cloud_server #{cloud_server.id}"
      provider_id
    end

    def server_status(provider_id)
      response = connection.get("instances/#{provider_id}")
      data = parse_response(response, "Vultr API error")

      vultr_to_status(data.dig("instance", "status"), data.dig("instance", "power_status"))
    end

    def server_ip(provider_id)
      response = connection.get("instances/#{provider_id}")
      data = parse_response(response, "Vultr API error")

      ip = data.dig("instance", "main_ip")
      ip == "0.0.0.0" ? nil : ip
    end

    def provision_phases
      [
        { key: "creating_vm", label: "Creating VM", icon: "fa-cloud", seconds: 55 },
        { key: "booting", label: "Installing game server", icon: "fa-server", seconds: 145 },
        { key: "configuring", label: "Sending configs", icon: "fa-cog", seconds: 15 },
        { key: "booting_tf2", label: "Starting TF2", icon: "fa-gamepad", seconds: 15 },
        { key: "starting_tf2", label: "Waiting for server", icon: "fa-hourglass-half", seconds: 15 }
      ]
    end

    def estimated_provision_time
      "about 4 minutes"
    end

    def destroy_server(provider_id)
      Rails.logger.info "Vultr: Destroying server #{provider_id}"
      response = connection.delete("instances/#{provider_id}")
      Rails.logger.info "Vultr: Destroy server #{provider_id} result: #{response.status}"
      response.success?
    end

    def destroy_servers_by_label(label)
      response = connection.get("instances?label=#{label}")
      return 0 unless response.success?

      data = JSON.parse(response.body)
      instances = data["instances"] || []
      destroyed = 0
      instances.each do |instance|
        if destroy_server(instance["id"])
          destroyed += 1
        end
      end
      Rails.logger.info "Vultr: Destroyed #{destroyed} servers with label #{label}" if destroyed > 0
      destroyed
    end

    def create_snapshot_server(location, setup_script)
      response = connection.post("instances") do |req|
        req.body = {
          label: "serveme-snapshot-#{Time.current.strftime('%Y%m%d%H%M')}",
          plan: plan,
          region: location,
          image_id: marketplace_image_id,
          sshkey_id: [ ssh_key_id ],
          user_data: Base64.strict_encode64(setup_script)
        }.to_json
      end
      data = parse_response(response, "Vultr API error")

      instance_id = data.dig("instance", "id")

      ip = nil
      90.times do
        sleep 5
        r = connection.get("instances/#{instance_id}")
        d = JSON.parse(r.body)
        status = d.dig("instance", "status")
        power = d.dig("instance", "power_status")
        candidate_ip = d.dig("instance", "main_ip")
        if status == "active" && power == "running" && candidate_ip.present? && candidate_ip != "0.0.0.0"
          ip = candidate_ip
          break
        end
      end
      raise "Vultr VM never became running" unless ip

      [ instance_id, ip ]
    end

    def halt_server(provider_id)
      connection.post("instances/halt") do |req|
        req.body = { instance_ids: [ provider_id ] }.to_json
      end
      60.times do
        sleep 2
        r = connection.get("instances/#{provider_id}")
        d = JSON.parse(r.body)
        return if d.dig("instance", "power_status") == "stopped"
      end
      raise "Vultr VM did not power off in time"
    end

    def create_snapshot(provider_id, description)
      response = connection.post("snapshots") do |req|
        req.body = { instance_id: provider_id, description: description }.to_json
      end
      data = parse_response(response, "Vultr snapshot error")

      data.dig("snapshot", "id")
    end

    def wait_for_snapshot(snapshot_id)
      360.times do
        sleep 5
        r = connection.get("snapshots/#{snapshot_id}")
        d = JSON.parse(r.body)
        status = d.dig("snapshot", "status")
        print "."
        return if status == "complete"
      end
      raise "Vultr snapshot did not complete in time"
    end

    def snapshot_credential_key
      "cloud_servers.vultr.snapshot_id"
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
      ENV["VULTR_API_KEY"] || Rails.application.credentials.dig(:cloud_servers, :vultr, :api_key)
    end

    def marketplace_image_id
      "docker" # Docker on Ubuntu 24.04 (marketplace)
    end

    def snapshot_id
      return nil if ENV["VULTR_NO_SNAPSHOT"]

      Rails.application.credentials.dig(:cloud_servers, :vultr, :snapshot_id)
    end

    def plan
      "vc2-2c-2gb"
    end

    def default_region
      "ewr"
    end

    def ssh_key_id
      Rails.application.credentials.dig(:cloud_servers, :vultr, :ssh_key_id)
    end

    def cloud_init_pre_docker
      <<~BASH.strip
        ufw disable || true
        iptables -F INPUT
        iptables -P INPUT ACCEPT
      BASH
    end

    PROXY_FALLBACK = {
      "EU" => "ams",
      "NA" => "ord"
    }.freeze

    def cloud_init_docker_pull(cloud_server, image)
      region = cloud_server.cloud_location || default_region
      location_info = LOCATIONS[region]
      fallback_region = PROXY_FALLBACK[location_info&.dig(:region)]
      mirror = "#{region}.vultrcr.com/docker.io/serveme/tf2-cloud-server:latest"

      pull_commands = []
      pull_commands << "(docker pull #{mirror} && docker tag #{mirror} #{image})"
      if fallback_region && fallback_region != region
        fallback_mirror = "#{fallback_region}.vultrcr.com/docker.io/serveme/tf2-cloud-server:latest"
        pull_commands << "(docker pull #{fallback_mirror} && docker tag #{fallback_mirror} #{image})"
      end
      pull_commands << "docker pull #{image}"

      <<~BASH.strip
        if ! docker image inspect #{image} >/dev/null 2>&1; then
          #{pull_commands.join(" || \\\n          ")}
        fi
      BASH
    end

    def vultr_to_status(status, power_status)
      case status
      when "pending" then "provisioning"
      when "active"
        power_status == "running" ? "running" : "stopped"
      when "suspended", "halted" then "stopped"
      else "provisioning"
      end
    end
  end
end
