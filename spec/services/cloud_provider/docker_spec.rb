# typed: false

require "spec_helper"

RSpec.describe CloudProvider::Docker do
  subject(:provider) { described_class.new }

  describe "#create_server" do
    let(:cloud_server) { create(:cloud_server, cloud_provider: "docker", cloud_callback_token: "test-token") }

    before do
      allow(File).to receive(:read)
        .with(Rails.root.join("tmp", "cloud_ssh_key.pub"))
        .and_return("ssh-ed25519 AAAA test@cloud\n")
      allow(provider).to receive(:system).and_return(true)
    end

    it "returns the container name as provider ID" do
      result = provider.create_server(cloud_server)
      expect(result).to eq("cloud-#{cloud_server.id}")
    end

    it "calls docker run with the correct arguments" do
      provider.create_server(cloud_server)

      expect(provider).to have_received(:system) do |*args|
        expect(args).to include("docker", "run", "-d", "--cap-add=NET_ADMIN")
        expect(args).to include("--name", "cloud-#{cloud_server.id}")
        expect(args).to include("-e", "CALLBACK_URL=http://host.docker.internal:3000/api/cloud_servers/#{cloud_server.id}/ready")
        expect(args).to include("-e", "CALLBACK_TOKEN=test-token")
        expect(args).to include("-e", "SSH_AUTHORIZED_KEYS=ssh-ed25519 AAAA test@cloud")
        expect(args).to include("tf2-cloud-server")
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
    it "always returns 127.0.0.1" do
      expect(provider.server_ip("cloud-1")).to eq("127.0.0.1")
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
