# typed: false
# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

describe DockerHostSetupService do
  let(:docker_host) { create(:docker_host, hostname: "de1.serveme.tf", ip: "1.2.3.4") }
  subject { described_class.new(docker_host) }

  describe "#create_vm" do
    let(:docker_host) { create(:docker_host, hostname: "de1.serveme.tf", ip: nil, provider: "hetzner", provider_location: "fsn1") }

    it "creates a Hetzner VM and assigns the IP" do
      hetzner = instance_double(CloudProvider::Hetzner)
      allow(CloudProvider::Hetzner).to receive(:new).and_return(hetzner)
      allow(hetzner).to receive(:create_bare_server)
        .with(name: "docker-host-de1-serveme-tf", location: "fsn1")
        .and_return([ "12345", "5.6.7.8" ])

      tcp_socket = instance_double(TCPSocket)
      allow(TCPSocket).to receive(:new).with("5.6.7.8", 22).and_return(tcp_socket)
      allow(tcp_socket).to receive(:close)

      result = subject.create_vm

      expect(result).to eq({ success: true, message: "Hetzner VM created (5.6.7.8) in fsn1" })
      expect(docker_host.reload.ip).to eq("5.6.7.8")
      expect(docker_host.provider_server_id).to eq("12345")
      expect(docker_host.setup_status).to eq("vm_created")
    end

    it "returns an error when no provider is configured" do
      docker_host.update_columns(provider: nil)

      result = subject.create_vm

      expect(result[:success]).to be false
      expect(result[:message]).to include("No cloud provider configured")
    end

    it "returns an error when VM already exists" do
      docker_host.update_columns(provider_server_id: "99999")

      result = subject.create_vm

      expect(result[:success]).to be false
      expect(result[:message]).to include("VM already created")
    end
  end

  describe "#check_dns" do
    context "with a serveme.tf hostname" do
      it "creates a Cloudflare A record when none exists" do
        dns_service = instance_double(CloudflareDnsService)
        allow(CloudflareDnsService).to receive(:new).and_return(dns_service)
        allow(dns_service).to receive(:record_exists?).with("de1.serveme.tf").and_return(false)
        allow(dns_service).to receive(:create_a_record).with("de1.serveme.tf", "1.2.3.4").and_return("record_123")

        result = subject.check_dns

        expect(dns_service).to have_received(:create_a_record)
        expect(result).to eq({ success: true, message: "DNS record created in Cloudflare" })
        expect(docker_host.reload.setup_status).to eq("dns_configured")
      end

      it "updates the Cloudflare A record when it already exists" do
        dns_service = instance_double(CloudflareDnsService)
        allow(CloudflareDnsService).to receive(:new).and_return(dns_service)
        allow(dns_service).to receive(:record_exists?).with("de1.serveme.tf").and_return(true)
        allow(dns_service).to receive(:update_a_record).with("de1.serveme.tf", "1.2.3.4").and_return("record_123")

        result = subject.check_dns

        expect(dns_service).to have_received(:update_a_record)
        expect(result).to eq({ success: true, message: "DNS record updated in Cloudflare" })
      end

      it "returns an error when Cloudflare API fails" do
        dns_service = instance_double(CloudflareDnsService)
        allow(CloudflareDnsService).to receive(:new).and_return(dns_service)
        allow(dns_service).to receive(:record_exists?).with("de1.serveme.tf").and_return(false)
        allow(dns_service).to receive(:create_a_record).and_raise(CloudflareDnsService::Error, "API error")

        result = subject.check_dns

        expect(result).to eq({ success: false, message: "Cloudflare API error: API error" })
      end
    end

    context "with a non-serveme.tf hostname" do
      let(:docker_host) { create(:docker_host, hostname: "server1.example.com", ip: "1.2.3.4") }

      it "verifies DNS resolves to the correct IP" do
        allow(Resolv).to receive(:getaddress).with("server1.example.com").and_return("1.2.3.4")

        result = subject.check_dns

        expect(result).to eq({ success: true, message: "DNS resolves correctly to 1.2.3.4" })
        expect(docker_host.reload.setup_status).to eq("dns_configured")
      end

      it "returns an error when DNS does not resolve" do
        allow(Resolv).to receive(:getaddress).with("server1.example.com").and_raise(Resolv::ResolvError)

        result = subject.check_dns

        expect(result).to eq({ success: false, message: "DNS for server1.example.com does not resolve. Please create an A record pointing to 1.2.3.4" })
      end

      it "returns an error when DNS resolves to wrong IP" do
        allow(Resolv).to receive(:getaddress).with("server1.example.com").and_return("9.9.9.9")

        result = subject.check_dns

        expect(result).to eq({ success: false, message: "DNS for server1.example.com resolves to 9.9.9.9, expected 1.2.3.4" })
      end
    end
  end

  describe "#check_ssh" do
    it "returns success when SSH connection works" do
      ssh = instance_double(Net::SSH::Connection::Session)
      allow(Net::SSH).to receive(:start).with("de1.serveme.tf", nil, hash_including(timeout: 5)).and_yield(ssh)
      allow(ssh).to receive(:exec!).with("hostname").and_return("de1\n")

      result = subject.check_ssh

      expect(result).to eq({ success: true, message: "SSH connection successful (hostname: de1)" })
      expect(docker_host.reload.setup_status).to eq("ssh_verified")
    end

    it "returns an error when SSH connection fails" do
      allow(Net::SSH).to receive(:start).and_raise(Net::SSH::AuthenticationFailed, "auth failed")

      result = subject.check_ssh

      expect(result[:success]).to be false
      expect(result[:message]).to include("SSH connection failed")
    end
  end

  describe "#provision_host" do
    let(:ssh) { instance_double(Net::SSH::Connection::Session) }

    before do
      allow(Net::SSH).to receive(:start).and_yield(ssh)
      allow(subject).to receive(:local_ssh_public_key).and_return("ssh-ed25519 AAAA fake-key")
    end

    it "runs each step, persists a setup log per step, and marks the host provisioned" do
      allow(subject).to receive(:ssh_exec_with_status).and_return([ "ok\n", 0 ])

      result = subject.provision_host

      expect(result).to eq({ success: true, message: "Host provisioned successfully" })
      expect(docker_host.reload.setup_status).to eq("provisioned")

      logs = docker_host.setup_logs.order(:created_at)
      expect(logs.map(&:step)).to eq(%w[install_prerequisites install_docker setup_app_user install_compose_services])
      expect(logs.map(&:success)).to all(be true)
      expect(logs.map(&:exit_status)).to all(eq(0))
      expect(logs.map(&:output)).to all(include("ok"))
    end

    it "stops at the first failed step, persists the failure log, and reports the error" do
      call_count = 0
      allow(subject).to receive(:ssh_exec_with_status) do
        call_count += 1
        if call_count == 2
          [ "apt failure: package not found\n", 100 ]
        else
          [ "ok\n", 0 ]
        end
      end

      result = subject.provision_host

      expect(result[:success]).to be false
      expect(result[:message]).to include("install_docker failed")
      expect(docker_host.setup_logs.count).to eq(2)
      expect(docker_host.setup_logs.last.success).to be false
      expect(docker_host.setup_logs.last.exit_status).to eq(100)
      expect(docker_host.setup_logs.last.output).to include("apt failure")
    end

    it "writes a compose file that pulls the EU-built images from Docker Hub" do
      script = subject.send(:install_compose_services_script)
      decoded_b64 = script.scan(/echo '([^']+)' \| base64 -d > .*docker-compose\.yml/).flatten.first
      compose = Base64.decode64(decoded_b64)
      expect(compose).to include("image: serveme/caddy-cloudflare:latest")
      expect(compose).to include("image: serveme/websocket-echo:latest")
      expect(compose).to include("network_mode: host")
      expect(compose).not_to include("build:")
    end

    it "runs docker compose pull and then up -d on the host" do
      script = subject.send(:install_compose_services_script)
      expect(script).to include("docker compose pull")
      expect(script).to include("docker compose up -d --remove-orphans")
    end

    it "removes the migration bootstrap sudo file as the very last action" do
      script = subject.send(:install_compose_services_script)
      expect(script).to include("rm -f /etc/sudoers.d/serveme-bootstrap")
      lines = script.lines.map(&:strip).reject(&:empty?)
      compose_up_idx = lines.index { |l| l.start_with?("docker compose up -d") }
      bootstrap_rm_idx = lines.index { |l| l == "rm -f /etc/sudoers.d/serveme-bootstrap" }
      expect(bootstrap_rm_idx).to be > compose_up_idx
    end

    context "when runs_caddy is false (web-app host with its own nginx)" do
      let(:docker_host) { create(:docker_host, hostname: "new.fakkelbrigade.eu", ip: "1.2.3.4", runs_caddy: false) }

      it "omits the caddy service + caddy volumes from the compose file" do
        compose = subject.send(:compose_yml)
        expect(compose).not_to include("caddy:")
        expect(compose).not_to include("caddy_data")
        expect(compose).not_to include("caddy_config")
        expect(compose).to include("websocket-echo:")
        expect(compose).to include("image: serveme/websocket-echo:latest")
      end

      it "does not disable nginx and does not write a Caddyfile" do
        script = subject.send(:install_compose_services_script)
        expect(script).not_to include("systemctl disable --now nginx.service")
        expect(script).not_to match(%r{> /opt/serveme-host/Caddyfile})
        expect(script).to include("rm -f /opt/serveme-host/Caddyfile")
      end

      it "still disables certbot + legacy caddy/websocket systemd units" do
        script = subject.send(:install_compose_services_script)
        expect(script).to include("systemctl disable --now caddy.service")
        expect(script).to include("systemctl disable --now certbot.timer certbot.service")
        expect(script).to include("systemctl disable --now websocket-echo.service websocket-echo-server.service")
      end
    end

    it "installs Docker via apt with signed repository (not via curl|sh)" do
      script = subject.send(:install_docker_script)
      expect(script).to include("/etc/apt/keyrings/docker.gpg")
      expect(script).to include("download.docker.com/linux/$repo_path")
      expect(script).to include("docker-ce")
      expect(script).to include("docker-compose-plugin")
      expect(script).not_to include("get.docker.com")
    end

    it "skips the Docker install when docker + compose are already present" do
      script = subject.send(:install_docker_script)
      expect(script).to include("if command -v docker")
      expect(script).to include("docker compose version >/dev/null 2>&1")
      expect(script).to match(/exit 0\b/)
    end

    it "supports both Ubuntu and Debian apt repos" do
      script = subject.send(:install_docker_script)
      expect(script).to include("ubuntu) repo_path=ubuntu")
      expect(script).to include("debian) repo_path=debian")
    end

    it "only apt-installs the prerequisites that are actually missing" do
      script = subject.send(:install_prerequisites_script)
      expect(script).to include("dpkg -s")
      expect(script).to include("missing+=(")
      expect(script).to include('"${missing[@]}"')
    end

    it "appends managed SSH keys to authorized_keys without removing operator-added ones" do
      allow(subject).to receive(:local_ssh_public_key).and_return("ssh-ed25519 LOCAL operator@admin")
      allow(subject).to receive(:cloud_ssh_public_key).and_return("ssh-ed25519 CLOUD cloud@worker")
      script = subject.send(:setup_app_user_script)
      expect(script).to include("touch \"$auth_keys\"")
      expect(script).to include("managed_keys=( 'ssh-ed25519 LOCAL operator@admin' )")
      expect(script).to include("managed_keys+=( 'ssh-ed25519 CLOUD cloud@worker' )")
      expect(script).to include('grep -qxF "$key" "$auth_keys" || echo "$key" >> "$auth_keys"')
      expect(script).not_to include("> /home/tf2/.ssh/authorized_keys")
    end

    it "writes iptables sudo to /etc/sudoers.d/serveme-iptables (never the operator-managed user file)" do
      allow(subject).to receive(:local_ssh_public_key).and_return("ssh-ed25519 LOCAL operator@admin")
      script = subject.send(:setup_app_user_script)
      expect(script).to include("> /etc/sudoers.d/serveme-iptables")
      expect(script).to include("chmod 440 /etc/sudoers.d/serveme-iptables")
      expect(script).to include("tf2 ALL=(root) NOPASSWD: /usr/sbin/iptables")
      expect(script).not_to match(%r{> /etc/sudoers\.d/tf2\b})
    end
  end

  describe "#check_ssl" do
    it "returns success when HTTPS is working" do
      stub_request(:get, "https://de1.serveme.tf/ping")
        .to_return(status: 200)

      result = subject.check_ssl

      expect(result).to eq({ success: true, message: "SSL certificate is valid and HTTPS is working" })
      expect(docker_host.reload.setup_status).to eq("ssl_verified")
    end

    it "returns an error when HTTPS is not working" do
      stub_request(:get, "https://de1.serveme.tf/ping")
        .to_raise(OpenSSL::SSL::SSLError.new("certificate verify failed"))

      result = subject.check_ssl

      expect(result[:success]).to be false
      expect(result[:message]).to include("SSL check failed")
    end
  end

  describe "#pull_image" do
    it "pulls the Docker image and marks host as ready" do
      ssh = instance_double(Net::SSH::Connection::Session)
      allow(Net::SSH).to receive(:start).and_yield(ssh)
      allow(ssh).to receive(:exec!).and_return("Status: Image is up to date")
      allow(ssh).to receive(:exec!).with("docker image inspect #{DockerHostSetupService::DOCKER_IMAGE} > /dev/null 2>&1 && echo EXISTS").and_return("EXISTS\n")

      result = subject.pull_image

      expect(result).to eq({ success: true, message: "Docker image pulled successfully" })
      expect(docker_host.reload.setup_status).to eq("ready")
    end

    it "returns an error when image is not present after pull" do
      ssh = instance_double(Net::SSH::Connection::Session)
      allow(Net::SSH).to receive(:start).and_yield(ssh)
      allow(ssh).to receive(:exec!).and_return("")

      result = subject.pull_image

      expect(result[:success]).to be false
      expect(result[:message]).to include("Image pull failed")
    end

    it "returns an error when connection fails" do
      allow(Net::SSH).to receive(:start).and_raise(StandardError, "connection refused")

      result = subject.pull_image

      expect(result[:success]).to be false
      expect(result[:message]).to include("Image pull failed")
    end
  end
end
