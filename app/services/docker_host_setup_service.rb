# typed: false
# frozen_string_literal: true

class DockerHostSetupService
  DOCKER_IMAGE = "serveme/tf2-cloud-server:latest"

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
      run_script(ssh, install_prerequisites_script)
      run_script(ssh, install_docker_script)
      run_script(ssh, setup_app_user_script)
      run_script(ssh, install_caddy_script)
      run_script(ssh, install_websocket_echo_server_script)
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

  def run_script(ssh, script)
    output = ssh.exec!("sudo bash -c #{Shellwords.shellescape(script)}")
    Rails.logger.info "DockerHostSetupService[#{docker_host.hostname}]: #{output&.strip&.lines&.last}"
    output
  end

  def install_prerequisites_script
    <<~BASH
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -qq
      apt-get install -y -qq curl git
      if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
        ufw allow 80/tcp
        ufw allow 443/tcp
        ufw allow #{docker_host.start_port}:#{docker_host.start_port + 100}/tcp
        ufw allow #{docker_host.start_port}:#{docker_host.start_port + 100}/udp
      fi
    BASH
  end

  def setup_app_user_script
    username = docker_host.ssh_user
    pub_key = local_ssh_public_key
    cloud_pub_key = cloud_ssh_public_key
    raise "No SSH public key found" unless pub_key

    <<~BASH
      export DEBIAN_FRONTEND=noninteractive
      id #{username} &>/dev/null || useradd -m -s /bin/bash #{username}
      usermod -aG docker #{username}
      mkdir -p /home/#{username}/.ssh
      chmod 700 /home/#{username}/.ssh
      echo '#{pub_key}' > /home/#{username}/.ssh/authorized_keys
      #{"echo '#{cloud_pub_key}' >> /home/#{username}/.ssh/authorized_keys" if cloud_pub_key}
      chmod 600 /home/#{username}/.ssh/authorized_keys
      chown -R #{username}:#{username} /home/#{username}/.ssh
      echo '#{username} ALL=(root) NOPASSWD: /usr/sbin/iptables' > /etc/sudoers.d/#{username}
      chmod 440 /etc/sudoers.d/#{username}
    BASH
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

  def install_docker_script
    <<~BASH
      export DEBIAN_FRONTEND=noninteractive
      if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com | sh
      fi
    BASH
  end

  def cloudflare_api_token
    Rails.application.credentials.dig(:cloudflare, :dns_api_token)
  end

  def install_caddy_script
    <<~BASH
      export DEBIAN_FRONTEND=noninteractive
      if ! command -v caddy &> /dev/null || ! caddy list-modules 2>/dev/null | grep -q cloudflare; then
        apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
        apt-get update -qq
        apt-get install -y caddy

        # Replace with custom build that includes Cloudflare DNS plugin
        systemctl stop caddy
        caddy_arch=$(dpkg --print-architecture)
        curl -fsSL "https://caddyserver.com/api/download?os=linux&arch=${caddy_arch}&p=github.com/caddy-dns/cloudflare" -o /usr/bin/caddy
        chmod +x /usr/bin/caddy
        systemctl start caddy
      fi
      cat > /etc/caddy/Caddyfile <<'CADDYFILE'
#{caddy_config}
CADDYFILE
      mkdir -p /etc/systemd/system/caddy.service.d
      cat > /etc/systemd/system/caddy.service.d/override.conf <<OVERRIDE
[Service]
Environment=CLOUDFLARE_API_TOKEN=#{cloudflare_api_token}
OVERRIDE
      chmod 600 /etc/systemd/system/caddy.service.d/override.conf
      systemctl daemon-reload
      systemctl restart caddy
    BASH
  end

  def caddy_config
    <<~CADDYFILE
      #{docker_host.hostname} {
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
          resolvers 1.1.1.1 8.8.8.8
        }
        reverse_proxy /ping localhost:8083
      }
    CADDYFILE
  end

  def install_websocket_echo_server_script
    <<~BASH
      export DEBIAN_FRONTEND=noninteractive
      if ! command -v node &> /dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
        apt-get install -y nodejs
      fi
      if [ ! -d /opt/websocket-echo-server ]; then
        git clone https://github.com/websockets/websocket-echo-server.git /opt/websocket-echo-server
        cd /opt/websocket-echo-server && npm install
      fi
      cat > /etc/systemd/system/websocket-echo.service <<'SYSTEMD'
[Unit]
Description=WebSocket Echo Server
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/websocket-echo-server
ExecStart=/usr/bin/node index.js
Environment=BIND_PORT=8083
Environment=BIND_ADDRESS=127.0.0.1
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SYSTEMD
      systemctl daemon-reload
      systemctl enable websocket-echo
      systemctl restart websocket-echo
    BASH
  end
end
