# typed: false

require "spec_helper"

RSpec.describe CloudProvider::Docker do
  subject(:provider) { described_class.new }

  describe "#create_server" do
    let(:cloud_server) { create(:cloud_server, cloud_provider: "docker", cloud_callback_token: "test-token", port: "27015") }

    before do
      allow(cloud_server).to receive(:cloud_ssh_public_key)
        .and_return("ssh-ed25519 AAAA test@cloud")
      allow(provider).to receive(:system).and_return(true)
    end

    it "returns the container name as provider ID" do
      result = provider.create_server(cloud_server)
      expect(result).to eq("res-#{cloud_server.cloud_reservation_id}-cloud-#{cloud_server.id}")
    end

    it "calls docker run with host networking and port env vars" do
      provider.create_server(cloud_server)

      expect(provider).to have_received(:system) do |*args|
        expect(args).to include("docker", "run", "-d", "--net=host")
        expect(args).to include("--security-opt", "seccomp=unconfined")
        expect(args).to include("--cap-drop=ALL")
        expect(args).to include("--cap-add=SETUID", "--cap-add=SETGID", "--cap-add=SYS_CHROOT", "--cap-add=AUDIT_WRITE")
        expect(args).to include("--name", "res-#{cloud_server.cloud_reservation_id}-cloud-#{cloud_server.id}")
        expect(args).to include("-e", "CALLBACK_URL=https://localhost/api/cloud_servers/#{cloud_server.id}/ready")
        expect(args).to include("-e", "CALLBACK_TOKEN=test-token")
        expect(args).to include("-e", "SSH_AUTHORIZED_KEYS=ssh-ed25519 AAAA test@cloud")
        expect(args).to include("-e", "PORT=27015")
        expect(args).to include("-e", "TV_PORT=27020")
        expect(args).to include("-e", "SSH_PORT=22000")
        expect(args).to include("-e", "CLIENT_PORT=40001")
        expect(args).to include("-e", "STEAM_PORT=30001")
        expect(args).to include("tf2-cloud-server")
      end
    end

    context "with a non-default port" do
      let(:cloud_server) { create(:cloud_server, cloud_provider: "docker", cloud_callback_token: "test-token", port: "27025") }

      it "passes correct port env vars for non-default port" do
        provider.create_server(cloud_server)

        expect(provider).to have_received(:system) do |*args|
          expect(args).to include("-e", "PORT=27025")
          expect(args).to include("-e", "TV_PORT=27030")
          expect(args).to include("-e", "SSH_PORT=22001")
          expect(args).to include("-e", "CLIENT_PORT=40002")
          expect(args).to include("-e", "STEAM_PORT=30002")
        end
      end
    end
  end

  describe "#server_status" do
    let(:success_status) { instance_double(Process::Status, success?: true) }
    let(:failure_status) { instance_double(Process::Status, success?: false) }

    it "returns 'running' for a running container" do
      allow(Open3).to receive(:capture2).with("docker", "inspect", "-f", "{{.State.Status}}", "cloud-1").and_return([ "running\n", success_status ])
      expect(provider.server_status("cloud-1")).to eq("running")
    end

    it "returns 'provisioning' for a created container" do
      allow(Open3).to receive(:capture2).with("docker", "inspect", "-f", "{{.State.Status}}", "cloud-1").and_return([ "created\n", success_status ])
      expect(provider.server_status("cloud-1")).to eq("provisioning")
    end

    it "returns 'provisioning' for a restarting container" do
      allow(Open3).to receive(:capture2).with("docker", "inspect", "-f", "{{.State.Status}}", "cloud-1").and_return([ "restarting\n", success_status ])
      expect(provider.server_status("cloud-1")).to eq("provisioning")
    end

    it "returns 'stopped' for an exited container" do
      allow(Open3).to receive(:capture2).with("docker", "inspect", "-f", "{{.State.Status}}", "cloud-1").and_return([ "exited\n", success_status ])
      expect(provider.server_status("cloud-1")).to eq("stopped")
    end

    it "returns 'stopped' for a dead container" do
      allow(Open3).to receive(:capture2).with("docker", "inspect", "-f", "{{.State.Status}}", "cloud-1").and_return([ "dead\n", success_status ])
      expect(provider.server_status("cloud-1")).to eq("stopped")
    end

    it "returns 'provisioning' for unknown status" do
      allow(Open3).to receive(:capture2).with("docker", "inspect", "-f", "{{.State.Status}}", "cloud-1").and_return([ "\n", success_status ])
      expect(provider.server_status("cloud-1")).to eq("provisioning")
    end

    it "returns 'provisioning' when docker inspect fails" do
      allow(Open3).to receive(:capture2).with("docker", "inspect", "-f", "{{.State.Status}}", "cloud-1").and_return([ "", failure_status ])
      expect(provider.server_status("cloud-1")).to eq("provisioning")
    end
  end

  describe "#server_ip" do
    it "uses DOCKER_HOST_IP env var when set" do
      allow(ENV).to receive(:fetch).with("DOCKER_HOST_IP").and_return("10.0.0.5")
      expect(provider.server_ip("cloud-1")).to eq("10.0.0.5")
    end

    it "falls back to hostname -I detection" do
      allow(ENV).to receive(:fetch).with("DOCKER_HOST_IP").and_call_original
      allow(Open3).to receive(:capture2).with("hostname", "-I").and_return([ "192.168.1.12 fd00::1\n", instance_double(Process::Status) ])
      expect(provider.server_ip("cloud-1")).to eq("192.168.1.12")
    end
  end

  describe "#destroy_server" do
    it "calls docker rm -f with the provider ID" do
      allow(provider).to receive(:system).and_return(true)

      result = provider.destroy_server("cloud-1")

      expect(result).to be true
      expect(provider).to have_received(:system).with("docker", "rm", "-f", "cloud-1")
    end
  end
end
