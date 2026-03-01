# typed: false
# frozen_string_literal: true

namespace :cloud do
  desc "Generate SSH keypair and callback token for local Docker cloud testing"
  task setup: :environment do
    key_path = Rails.root.join("tmp", "cloud_ssh_key")
    token_path = Rails.root.join("tmp", "cloud_callback_token")

    if File.exist?(key_path)
      puts "SSH keypair already exists at #{key_path}"
    else
      system("ssh-keygen", "-t", "ed25519", "-f", key_path.to_s, "-N", "", "-C", "cloud-test", exception: true)
      puts "Generated SSH keypair at #{key_path}"
    end

    if File.exist?(token_path)
      puts "Callback token already exists at #{token_path}"
    else
      File.write(token_path, SecureRandom.hex(32))
      puts "Generated callback token at #{token_path}"
    end

    puts "\nSetup complete. Run 'rake cloud:test' to test the phone-home callback flow."
  end

  desc "Test cloud server phone-home callback with local Docker"
  task test: :environment do
    key_path = Rails.root.join("tmp", "cloud_ssh_key")
    token_path = Rails.root.join("tmp", "cloud_callback_token")

    unless File.exist?(key_path) && File.exist?(token_path)
      abort "Run 'rake cloud:setup' first to generate SSH keys and callback token."
    end

    location = Location.find_or_create_by!(name: "Local Docker") do |l|
      l.flag = "eu"
    end

    user = User.first
    abort "No users in database. Run 'rake db:seed' first." unless user

    server_config = ServerConfig.first
    abort "No server configs in database. Run 'rake db:seed' first." unless server_config

    server = CloudServer.create!(
      name: "Docker Cloud Test #{Time.current.strftime('%H:%M:%S')}",
      ip: "127.0.0.1",
      port: "27015",
      path: "/home/tf2/hlserver/tf2",
      rcon: SecureRandom.hex(8),
      cloud_provider: "docker",
      cloud_status: "provisioning",
      cloud_location: "local",
      cloud_ssh_port: 2222,
      cloud_created_at: Time.current,
      location: location
    )

    reservation = Reservation.create!(
      server: server,
      user: user,
      server_config: server_config,
      password: "test123",
      rcon: "testrcon",
      starts_at: Time.current,
      ends_at: 2.hours.from_now
    )

    server.update!(cloud_reservation_id: reservation.id)

    container_name = "cloud-#{server.id}"

    puts "=" * 60
    puts "Cloud Server Phone-Home Test"
    puts "=" * 60
    puts "Server ID:        #{server.id}"
    puts "Reservation ID:   #{reservation.id}"
    puts "Cloud Status:     #{server.cloud_status}"
    puts "Container:        #{container_name}"
    puts "SSH port:         127.0.0.1:2222"
    puts "=" * 60

    docker_dir = Rails.root.join("docker", "tf2-cloud-server")

    puts "\nBuilding Docker image..."
    unless system({ "DOCKER_BUILDKIT" => "0" }, "docker", "build", "-t", "tf2-cloud-server", docker_dir.to_s)
      abort "Docker build failed"
    end

    puts "\nStarting container via Docker provider..."
    provider_id = server.provider.create_server(server)
    server.update!(cloud_provider_id: provider_id)

    puts "\nContainer started. Waiting for two-phase callback flow..."
    puts "(follow logs in another terminal: docker logs -f #{container_name})\n\n"

    # Phase 1: Wait for ssh_ready callback (triggers config push automatically)
    puts "[1/3] Waiting for ssh_ready callback..."
    60.times do |i|
      sleep 5
      server.reload
      elapsed = (i + 1) * 5
      print "\r  [#{elapsed}s] cloud_status=#{server.cloud_status}"
      break if server.cloud_status.in?(%w[ssh_ready ready])
    end

    unless server.cloud_status.in?(%w[ssh_ready ready])
      puts "\n\nTimeout after 300s. ssh_ready callback not received."
      puts "Check container logs:  docker logs #{container_name}"
      puts "\nClean up:  rake cloud:cleanup"
      exit 1
    end
    puts "\n  ssh_ready received! Config push triggered automatically."

    # Phase 2: Wait for tf2_ready callback + reservation provisioned
    puts "\n[2/3] Waiting for TF2 to boot and reservation to be provisioned..."
    60.times do |i|
      sleep 5
      server.reload
      reservation.reload
      elapsed = (i + 1) * 5
      print "\r  [#{elapsed}s] cloud_status=#{server.cloud_status} provisioned=#{reservation.provisioned?}"
      break if reservation.provisioned?
    end

    puts "\n\n  Reservation status log:"
    reservation.reservation_statuses.order(:id).each do |s|
      puts "    - #{s.status}"
    end

    unless reservation.provisioned?
      puts "\nTimeout after 300s. Reservation not provisioned."
      puts "Check container logs:  docker logs #{container_name}"
      puts "\nClean up:  rake cloud:cleanup"
      exit 1
    end
    puts "\n  Reservation provisioned!"

    # Phase 3: RCON check
    puts "\n[3/3] Testing RCON (password: #{reservation.rcon})..."
    sleep 5
    server.reload
    rcon_output = nil
    6.times do |attempt|
      begin
        condenser = SteamCondenser::Servers::SourceServer.new(server.ip, server.port.to_i)
        condenser.rcon_auth(reservation.rcon)
        rcon_output = condenser.rcon_exec("status")
        condenser.disconnect
        break
      rescue SteamCondenser::Error::RCONBan, SteamCondenser::Error::Timeout, Errno::ECONNREFUSED => e
        puts "  Attempt #{attempt + 1}/6 failed: #{e.class} - #{e.message}"
        sleep 5
      end
    end

    if rcon_output.present?
      puts "\nRCON status output:"
      puts "-" * 60
      puts rcon_output
      puts "-" * 60
      puts "\nEnd-to-end test PASSED!"
    else
      puts "\nRCON returned empty output or could not connect. Test FAILED."
      exit 1
    end

    puts "\nClean up when done:"
    puts "  rake cloud:cleanup"
  end

  desc "Test a cloud provider end-to-end: CLOUD_CALLBACK_HOST=ariekanarie.nl:3000 rake cloud:smoke[hetzner,fsn1]"
  task :smoke, [ :provider, :location ] => :environment do |_t, args|
    provider_name = args[:provider]
    location_code = args[:location]

    abort <<~USAGE unless provider_name && location_code
      Usage: CLOUD_CALLBACK_HOST=ariekanarie.nl:3000 rake cloud:smoke[provider,location]
        e.g. rake cloud:smoke[hetzner,fsn1]
             rake cloud:smoke[vultr,ewr]
      Set CLOUD_CALLBACK_HOST to your public host:port for the full e2e test (callback + RCON).
      Without it, only the API lifecycle (create/poll/destroy) is tested.
    USAGE

    e2e = ENV["CLOUD_CALLBACK_HOST"].present?

    user = User.first
    abort "No users in database. Run 'rake db:seed' first." unless user

    server_config = ServerConfig.first
    abort "No server configs in database. Run 'rake db:seed' first." unless server_config

    rcon_password = SecureRandom.hex(4)

    begin
      server = CloudServer.build_for_location(provider_name, location_code, rcon: rcon_password)
    rescue ArgumentError => e
      abort e.message
    end
    server.save!

    reservation = Reservation.create!(
      server: server,
      user: user,
      server_config: server_config,
      password: "test123",
      rcon: rcon_password,
      starts_at: Time.current,
      ends_at: 2.hours.from_now
    )

    server.update!(cloud_reservation_id: reservation.id)

    provider = server.provider
    started_at = Time.current

    puts "=" * 60
    puts "Cloud Provider Smoke Test"
    puts "=" * 60
    puts "Provider:       #{provider_name}"
    puts "Location:       #{server.location.name} (#{location_code})"
    puts "Server ID:      #{server.id}"
    puts "Reservation ID: #{reservation.id}"
    puts "RCON password:  #{rcon_password}"
    puts "Mode:           #{e2e ? 'Full e2e (callback + RCON)' : 'API lifecycle only'}"
    if e2e
      puts "Callback host:  #{ENV['CLOUD_CALLBACK_HOST']}"
    else
      puts ""
      puts "Tip: set CLOUD_CALLBACK_HOST=ariekanarie.nl:3000 for full e2e"
    end
    puts "=" * 60

    cleanup = lambda do
      puts "\nCleaning up..."
      if server.cloud_provider_id.present?
        provider.destroy_server(server.cloud_provider_id) rescue nil
        puts "  Destroyed #{provider_name} VM #{server.cloud_provider_id}"
      end
      reservation.destroy
      server.destroy
    end

    # Step 1: Create VM
    puts "\n[1/5] Creating VM..."
    begin
      provider_id = provider.create_server(server)
      server.update!(cloud_provider_id: provider_id)
      puts "  OK - provider_id: #{provider_id} (#{(Time.current - started_at).round(1)}s)"
    rescue => e
      puts "  FAILED: #{e.class} - #{e.message}"
      reservation.destroy
      server.destroy
      abort "\nSmoke test failed at create step."
    end

    # Step 2: Poll status until running + IP assigned
    puts "\n[2/5] Waiting for VM to be running with IP..."
    ip = nil
    90.times do |i|
      sleep 5
      elapsed = (i + 1) * 5
      begin
        status = provider.server_status(provider_id)
        ip = provider.server_ip(provider_id) if status == "running"
        print "\r  [#{elapsed}s] status=#{status} ip=#{ip || 'pending'}      "
        if status == "running" && ip
          server.update!(ip: ip)
          puts "\n  OK - running at #{ip} (#{(Time.current - started_at).round(1)}s)"
          break
        end
      rescue => e
        print "\r  [#{elapsed}s] poll error: #{e.class}      "
      end
    end

    unless ip
      puts "\n  TIMEOUT after 450s"
      cleanup.call
      abort "\nSmoke test failed: VM never became ready."
    end

    if e2e
      # Step 3: Wait for phone-home callback
      puts "\n[3/5] Waiting for phone-home callback..."
      puts "  (VM is pulling Docker image and booting TF2, this takes 2-4 min)"
      callback_received = false
      90.times do |i|
        sleep 5
        server.reload
        elapsed = (i + 1) * 5
        print "\r  [#{elapsed}s] cloud_status=#{server.cloud_status}      "
        if server.cloud_status == "ready"
          puts "\n  OK - callback received (#{(Time.current - started_at).round(1)}s)"
          callback_received = true
          break
        end
      end

      unless callback_received
        puts "\n  TIMEOUT after 450s - callback not received."
        puts "  Check Rails server logs for incoming requests from #{ip}"
        puts "\n  Clean up with: rake cloud:cleanup[#{provider_name}]"
        abort "\nSmoke test failed at callback step."
      end

      # Step 4: Wait for reservation to be provisioned
      # The callback controller already triggers ReservationWorker to start it
      puts "\n[4/5] Waiting for reservation to be provisioned..."
      provisioned = false
      24.times do |i|
        sleep 5
        reservation.reload
        elapsed = (i + 1) * 5
        print "\r  [#{elapsed}s] provisioned=#{reservation.provisioned?}      "
        if reservation.provisioned?
          puts "\n  OK - reservation provisioned (#{(Time.current - started_at).round(1)}s)"
          provisioned = true
          break
        end
      end

      puts "\n  Reservation status log:"
      reservation.reservation_statuses.order(:id).each do |s|
        puts "    - #{s.status}"
      end

      unless provisioned
        puts "\n  Reservation not provisioned after 120s. Continuing to RCON check anyway..."
      end

      puts "\n  Waiting for server to finish loading..."
      sleep 30

      # Step 5: RCON check — first check if srcds is alive via SSH
      puts "\n[5/5] Testing RCON (password: #{rcon_password})..."
      begin
        server.reload
        server.instance_variable_set(:@ssh, nil) # force new SSH connection
        ps_output = server.execute("ps aux | grep srcds | grep -v grep", log: false)
        if ps_output.present?
          ps_output.strip.lines.each { |l| puts "  process: #{l.strip}" }
        else
          puts "  WARNING: srcds process NOT found on remote server!"
        end
        port_check = server.execute("ss -tuln | grep :27015", log: false)
        port_check.strip.lines.each { |l| puts "  port: #{l.strip}" } if port_check.present?
        # Try RCON from inside the VM
        internal_rcon = server.execute("echo status | timeout 3 nc -q1 127.0.0.1 27015 2>&1 || echo 'NC_FAILED'", log: false)
        puts "  internal TCP 27015: #{internal_rcon&.strip&.truncate(200)}"
      rescue => e
        puts "  SSH check failed: #{e.class} - #{e.message}"
      end

      rcon_output = nil
      6.times do |attempt|
        begin
          condenser = SteamCondenser::Servers::SourceServer.new(server.ip, server.port.to_i)
          condenser.rcon_auth(reservation.rcon)
          rcon_output = condenser.rcon_exec("status")
          condenser.disconnect
          break
        rescue SteamCondenser::Error::RCONBan, SteamCondenser::Error::Timeout, Errno::ECONNREFUSED => e
          puts "  Attempt #{attempt + 1}/6 failed: #{e.class} - #{e.message}"
          sleep 10
        end
      end

      if rcon_output.present?
        puts "\n  RCON status output:"
        puts "  " + "-" * 56
        rcon_output.each_line { |l| puts "  #{l}" }
        puts "  " + "-" * 56
      else
        puts "\n  WARNING: RCON returned empty output or could not connect."
      end
    else
      puts "\n[3/5] Skipping callback (no CLOUD_CALLBACK_HOST set)"
      puts "\n[4/5] Skipping reservation start"
      puts "\n[5/5] Skipping RCON check"
    end

    # Destroy
    puts "\n[cleanup] Destroying VM..."
    begin
      result = provider.destroy_server(provider_id)
      puts "  OK - VM destroyed (#{(Time.current - started_at).round(1)}s)" if result
    rescue => e
      puts "  FAILED: #{e.class} - #{e.message}"
    end

    reservation.destroy
    server.destroy
    total = (Time.current - started_at).round(1)

    puts "\n" + "=" * 60
    if e2e && rcon_output.present?
      puts "End-to-end test PASSED (#{total}s)"
      puts "  create -> running -> ip=#{ip} -> callback -> reservation -> RCON -> destroyed"
    elsif e2e
      puts "Test PARTIAL (#{total}s) - RCON failed but API + callback worked"
      puts "  create -> running -> ip=#{ip} -> callback -> RCON failed -> destroyed"
    else
      puts "API smoke test PASSED (#{total}s)"
      puts "  create -> running -> ip=#{ip} -> destroyed"
    end
    puts "=" * 60
  end

  desc "Create a snapshot with Docker image pre-pulled: rake cloud:snapshot[hetzner,fsn1] or rake cloud:snapshot[vultr,ewr]"
  task :snapshot, [ :provider, :location ] => :environment do |_t, args|
    provider_name = args[:provider] || "hetzner"
    location = args[:location] || (provider_name == "hetzner" ? "fsn1" : "ewr")
    provider = CloudProvider.for(provider_name)
    setup_script = <<~BASH
      #!/bin/bash
      docker pull serveme/tf2-cloud-server:latest
      touch /tmp/image-ready
    BASH

    # 1. Create temp VM
    puts "Creating temporary VM in #{location}..."
    server_id, ip = provider.create_snapshot_server(location, setup_script)
    puts "  VM running at #{ip}"

    # 2. Wait for Docker image pull (SSH check for /tmp/image-ready)
    ssh_key_file = CloudServer.new.send(:cloud_ssh_key_file)
    print "  Waiting for docker pull to complete..."
    image_ready = false
    180.times do
      result = `ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i #{ssh_key_file} root@#{ip} 'test -f /tmp/image-ready && echo READY' 2>/dev/null`.strip
      if result == "READY"
        puts " done!"
        image_ready = true
        break
      end
      print "."
      sleep 5
    end
    abort "\n  ERROR: Docker image pull did not complete in time. Destroy the VM manually." unless image_ready

    # 3. Verify image
    images = `ssh -o StrictHostKeyChecking=no -i #{ssh_key_file} root@#{ip} 'docker images serveme/tf2-cloud-server --format "{{.Size}}"' 2>/dev/null`.strip
    puts "  Image size: #{images}"

    # 4. Halt, snapshot, wait, destroy
    puts "  Powering off VM..."
    provider.halt_server(server_id)

    description = "serveme-cloud-#{Time.current.strftime('%Y%m%d')}"
    puts "  Creating snapshot..."
    snapshot_id = provider.create_snapshot(server_id, description)
    puts "  Snapshot ID: #{snapshot_id}"

    print "  Waiting for snapshot to finish..."
    provider.wait_for_snapshot(snapshot_id)
    puts " done!"

    puts "  Destroying temporary VM..."
    provider.destroy_server(server_id)

    puts "\n" + "=" * 60
    puts "Snapshot ready!"
    puts "  Snapshot ID: #{snapshot_id}"
    puts "  Add to credentials: #{provider.snapshot_credential_key}: #{snapshot_id}"
    puts "=" * 60
  end

  desc "Clean up cloud test server records and VMs: rake cloud:cleanup or rake cloud:cleanup[hetzner]"
  task :cleanup, [ :provider ] => :environment do |_t, args|
    providers = if args[:provider]
      [ args[:provider] ]
    else
      %w[docker remote_docker hetzner vultr]
    end

    providers.each do |provider_name|
      servers = CloudServer.where(cloud_provider: provider_name)
      if servers.any?
        puts "Removing #{servers.count} #{provider_name} cloud server(s)..."
        servers.each do |server|
          if server.cloud_provider_id.present?
            begin
              server.provider.destroy_server(server.cloud_provider_id)
              puts "  Destroyed #{provider_name} server #{server.cloud_provider_id}"
            rescue => e
              puts "  Failed to destroy #{server.cloud_provider_id}: #{e.message}"
            end
          end
        end
        reservation_ids = servers.pluck(:cloud_reservation_id).compact
        servers.destroy_all
        if reservation_ids.any?
          Reservation.where(id: reservation_ids).destroy_all
        end
      else
        puts "No #{provider_name} cloud server records found."
      end
    end
    puts "Done."
  end
end
