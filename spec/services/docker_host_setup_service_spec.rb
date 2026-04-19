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
      allow(Net::SSH).to receive(:start).with("1.2.3.4", nil, hash_including(timeout: 5)).and_yield(ssh)
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
    end

    it "installs Docker, Caddy, and websocket echo server" do
      allow(ssh).to receive(:exec!).and_return("ok")

      result = subject.provision_host

      expect(ssh).to have_received(:exec!).at_least(3).times
      expect(result).to eq({ success: true, message: "Host provisioned successfully" })
      expect(docker_host.reload.setup_status).to eq("provisioned")
    end

    it "returns an error when provisioning fails" do
      allow(Net::SSH).to receive(:start).and_raise(StandardError, "connection refused")

      result = subject.provision_host

      expect(result[:success]).to be false
      expect(result[:message]).to include("Provisioning failed")
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
      allow(ssh).to receive(:exec!).with("sudo docker image inspect #{DockerHostSetupService::DOCKER_IMAGE} > /dev/null 2>&1 && echo EXISTS").and_return("EXISTS\n")

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
