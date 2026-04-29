# typed: false
# frozen_string_literal: true

require "base64"

class DockerHostSetupService
  DOCKER_IMAGE = "serveme/tf2-cloud-server:latest"
  CADDY_IMAGE = "serveme/caddy-cloudflare:latest"
  WEBSOCKET_ECHO_IMAGE = "serveme/websocket-echo:latest"

  # Set to e.g. "5:27.5.1-1~ubuntu.24.04~noble" to lock the docker-ce
  # package; empty string tracks the apt repo's current.
  DOCKER_CE_VERSION = ""

  COMPOSE_DIR = "/opt/serveme-host"

  attr_reader :docker_host

  def initialize(docker_host)
    @docker_host = docker_host
  end

  def create_vm
    raise "No cloud provider configured" unless docker_host.provider?
    raise "VM already created" if docker_host.provider_server_id.present?

    provider = cloud_provider
    server_id, ip = provider.create_bare_server(
      name: "docker-host-#{docker_host.hostname.tr('.', '-')}",
      location: docker_host.provider_location
    )

    docker_host.update!(provider_server_id: server_id, ip: ip)
    wait_for_ssh(ip)
    docker_host.update!(setup_status: "vm_created")
    { success: true, message: "#{docker_host.provider.capitalize} VM created (#{ip}) in #{docker_host.provider_location}" }
  rescue StandardError => e
    { success: false, message: "VM creation failed: #{e.message}" }
  end

  def check_dns
    if docker_host.serveme_hostname?
      configure_cloudflare_dns
    else
      verify_external_dns
    end
  end

  def check_ssh
    ssh_to_host do |ssh|
      hostname = ssh.exec!("hostname").to_s.strip
      docker_host.update!(setup_status: "ssh_verified")
      { success: true, message: "SSH connection successful (hostname: #{hostname})" }
    end
  rescue Net::SSH::AuthenticationFailed, Errno::ECONNREFUSED, Errno::ETIMEDOUT, SocketError, StandardError => e
    { success: false, message: "SSH connection failed: #{e.message}" }
  end

  def provision_host
    ssh_to_host do |ssh|
      run_script(ssh, "install_prerequisites", install_prerequisites_script)
      run_script(ssh, "install_docker", install_docker_script)
      run_script(ssh, "setup_app_user", setup_app_user_script)
      run_script(ssh, "install_compose_services", install_compose_services_script)
      docker_host.update!(setup_status: "provisioned")
      { success: true, message: "Host provisioned successfully" }
    end
  rescue StandardError => e
    { success: false, message: "Provisioning failed: #{e.message}" }
  end

  def check_ssl
    attempts = docker_host.provider? ? 12 : 1
    last_error = nil
    attempts.times do |attempt|
      uri = URI("https://#{docker_host.hostname}/ping")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 5

      http.request(Net::HTTP::Get.new(uri))
      docker_host.update!(setup_status: "ssl_verified")
      return { success: true, message: "SSL certificate is valid and HTTPS is working" }
    rescue StandardError => e
      last_error = e
      sleep 10 if attempt < attempts - 1
    end
    { success: false, message: "SSL check failed: #{last_error&.message}" }
  end

  def pull_image
    ssh_to_host do |ssh|
      output = ssh.exec!("docker pull #{DOCKER_IMAGE} && docker image prune -f")
      image_check = ssh.exec!("docker image inspect #{DOCKER_IMAGE} > /dev/null 2>&1 && echo EXISTS").to_s.strip
      raise "Image not found after pull. Output: #{output&.strip&.lines&.last}" unless image_check.include?("EXISTS")

      docker_host.update!(setup_status: "ready")
      { success: true, message: "Docker image pulled successfully" }
    end
  rescue StandardError => e
    { success: false, message: "Image pull failed: #{e.message}" }
  end

  private

  def cloud_provider
    case docker_host.provider
    when "hetzner" then CloudProvider::Hetzner.new
    when "vultr" then CloudProvider::Vultr.new
    else raise "Unknown provider: #{docker_host.provider}"
    end
  end

  def configure_cloudflare_dns
    dns_service = CloudflareDnsService.new
    if dns_service.record_exists?(docker_host.hostname)
      dns_service.update_a_record(docker_host.hostname, docker_host.ip)
      docker_host.update!(setup_status: "dns_configured")
      { success: true, message: "DNS record updated in Cloudflare" }
    else
      dns_service.create_a_record(docker_host.hostname, docker_host.ip)
      docker_host.update!(setup_status: "dns_configured")
      { success: true, message: "DNS record created in Cloudflare" }
    end
  rescue CloudflareDnsService::Error => e
    { success: false, message: "Cloudflare API error: #{e.message}" }
  end

  def verify_external_dns
    resolved_ip = Resolv.getaddress(docker_host.hostname)
    if resolved_ip == docker_host.ip
      docker_host.update!(setup_status: "dns_configured")
      { success: true, message: "DNS resolves correctly to #{docker_host.ip}" }
    else
      { success: false, message: "DNS for #{docker_host.hostname} resolves to #{resolved_ip}, expected #{docker_host.ip}" }
    end
  rescue Resolv::ResolvError
    { success: false, message: "DNS for #{docker_host.hostname} does not resolve. Please create an A record pointing to #{docker_host.ip}" }
  end

  def wait_for_ssh(ip, attempts: 30, delay: 5)
    attempts.times do
      TCPSocket.new(ip, 22).close
      return
    rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, SocketError
      sleep delay
    end
    raise "SSH port not reachable on #{ip} after #{attempts * delay}s"
  end

  def ssh_to_host(&block)
    opts = { timeout: 5, keepalive: true, keepalive_interval: 5, keepalive_maxcount: 2, bind_address: "0.0.0.0" }

    if docker_host.provider?
      host = docker_host.ip
      user = "root"
      key_data = Rails.application.credentials.dig(:cloud_servers, :ssh_private_key)
      if key_data.present?
        opts[:key_data] = [ key_data ]
        opts[:keys_only] = true
      end
      opts[:verify_host_key] = :never
    else
      host = docker_host.hostname
      user = nil
    end

    Net::SSH.start(host, user, **opts, &block)
  end

  # Raises on non-zero exit so a failed step doesn't silently let the next
  # one run — `ssh.exec!` discarded exit codes and used to mask failures.
  def run_script(ssh, step, script)
    cmd = "sudo bash -c #{Shellwords.shellescape(script)} 2>&1"
    output, exit_status = ssh_exec_with_status(ssh, cmd)

    success = exit_status == 0
    docker_host.setup_logs.create!(step: step, success: success, output: output, exit_status: exit_status) if docker_host.persisted?
    Rails.logger.info "DockerHostSetupService[#{docker_host.hostname}] #{step}: exit=#{exit_status}, last=#{output.lines.last&.strip}"
    raise "#{step} failed (exit #{exit_status}). Last line: #{output.lines.last&.strip}" unless success
    output
  end

  def ssh_exec_with_status(ssh, cmd)
    output = +""
    exit_status = nil
    channel = ssh.open_channel do |ch|
      ch.exec(cmd) do |c, ok|
        raise "ssh exec failed" unless ok
        c.on_data { |_, data| output << data }
        c.on_extended_data { |_, _, data| output << data }
        c.on_request("exit-status") { |_, data| exit_status = data.read_long }
      end
    end
    channel.wait
    [ output, exit_status ]
  end

  def install_prerequisites_script
    <<~BASH
      set -e
      export DEBIAN_FRONTEND=noninteractive
      missing=()
      for pkg in curl ca-certificates gnupg; do
        dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
      done
      if [ ${#missing[@]} -gt 0 ]; then
        apt-get update -qq
        apt-get install -y -qq "${missing[@]}"
      fi
      if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
        ufw allow 80/tcp
        ufw allow 443/tcp
        ufw allow #{docker_host.start_port}:#{docker_host.start_port + 100}/tcp
        ufw allow #{docker_host.start_port}:#{docker_host.start_port + 100}/udp
      fi
    BASH
  end

  def install_docker_script
    pin = DOCKER_CE_VERSION.empty? ? "" : "=#{DOCKER_CE_VERSION}"
    <<~BASH
      set -e
      export DEBIAN_FRONTEND=noninteractive
      if command -v docker >/dev/null && docker compose version >/dev/null 2>&1; then
        systemctl enable --now docker >/dev/null 2>&1 || true
        docker --version
        docker compose version
        exit 0
      fi
      . /etc/os-release
      case "$ID" in
        ubuntu) repo_path=ubuntu ;;
        debian) repo_path=debian ;;
        *) echo "Unsupported OS for Docker apt repo: $ID" >&2; exit 1 ;;
      esac
      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL "https://download.docker.com/linux/$repo_path/gpg" \
        | gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
      chmod a+r /etc/apt/keyrings/docker.gpg
      arch="$(dpkg --print-architecture)"
      echo "deb [arch=$arch signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$repo_path $VERSION_CODENAME stable" \
        > /etc/apt/sources.list.d/docker.list
      apt-get update -qq
      apt-get install -y -qq \
        docker-ce#{pin} docker-ce-cli#{pin} containerd.io \
        docker-buildx-plugin docker-compose-plugin
      systemctl enable --now docker >/dev/null 2>&1 || true
      docker --version
      docker compose version
    BASH
  end

  def setup_app_user_script
    username = docker_host.ssh_user
    pub_key = local_ssh_public_key
    cloud_pub_key = cloud_ssh_public_key
    raise "No SSH public key found" unless pub_key

    <<~BASH
      set -e
      export DEBIAN_FRONTEND=noninteractive
      id #{username} &>/dev/null || useradd -m -s /bin/bash #{username}
      usermod -aG docker #{username}
      install -d -m 0700 -o #{username} -g #{username} /home/#{username}/.ssh
      echo '#{pub_key}' > /home/#{username}/.ssh/authorized_keys
      #{"echo '#{cloud_pub_key}' >> /home/#{username}/.ssh/authorized_keys" if cloud_pub_key}
      chmod 600 /home/#{username}/.ssh/authorized_keys
      chown -R #{username}:#{username} /home/#{username}/.ssh
      echo '#{username} ALL=(root) NOPASSWD: /usr/sbin/iptables' > /etc/sudoers.d/#{username}
      chmod 440 /etc/sudoers.d/#{username}
    BASH
  end

  def install_compose_services_script
    compose_b64 = Base64.strict_encode64(compose_yml)
    caddyfile_b64 = Base64.strict_encode64(caddyfile_content)
    <<~BASH
      set -e
      install -d -m 0755 #{COMPOSE_DIR}
      echo '#{compose_b64}' | base64 -d > #{COMPOSE_DIR}/docker-compose.yml
      echo '#{caddyfile_b64}' | base64 -d > #{COMPOSE_DIR}/Caddyfile

      # Disable services from prior provisioning eras so they release
      # ports 80 / 443 / 8083 before compose claims them. All idempotent.
      rm -f #{COMPOSE_DIR}/.env
      systemctl disable --now nginx.service 2>/dev/null || true
      systemctl disable --now caddy.service 2>/dev/null || true
      systemctl disable --now certbot.timer certbot.service 2>/dev/null || true
      systemctl disable --now websocket-echo.service websocket-echo-server.service 2>/dev/null || true

      cd #{COMPOSE_DIR}
      docker compose pull 2>&1 || echo "[install_compose_services] pull failed; relying on local images"
      docker compose up -d --remove-orphans
    BASH
  end

  def compose_yml
    <<~YAML
      services:
        caddy:
          image: #{CADDY_IMAGE}
          container_name: serveme-host-caddy
          network_mode: host
          restart: unless-stopped
          volumes:
            - ./Caddyfile:/etc/caddy/Caddyfile:ro
            - caddy_data:/data
            - caddy_config:/config
        websocket-echo:
          image: #{WEBSOCKET_ECHO_IMAGE}
          container_name: serveme-host-websocket-echo
          network_mode: host
          restart: unless-stopped
          environment:
            BIND_PORT: "8083"
            BIND_ADDRESS: "127.0.0.1"
      volumes:
        caddy_data:
        caddy_config:
    YAML
  end

  # Port 80 must be reachable from the public internet at this hostname —
  # Caddy auto-issues via HTTP-01.
  def caddyfile_content
    <<~CADDYFILE
      #{docker_host.hostname} {
        reverse_proxy /ping localhost:8083
      }
    CADDYFILE
  end

  def local_ssh_public_key
    %w[id_rsa.pub id_ed25519.pub id_ecdsa.pub].each do |name|
      path = File.expand_path("~/.ssh/#{name}")
      return File.read(path).strip if File.exist?(path)
    end
    nil
  end

  def cloud_ssh_public_key
    key_data = Rails.application.credentials.dig(:cloud_servers, :ssh_private_key)
    return nil unless key_data.present?

    key = Net::SSH::KeyFactory.load_data_private_key(key_data)
    "#{key.ssh_type} #{[ key.to_blob ].pack('m0')}"
  rescue StandardError
    nil
  end
end
