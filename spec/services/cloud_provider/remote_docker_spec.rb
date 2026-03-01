# typed: false

require "spec_helper"

RSpec.describe CloudProvider::RemoteDocker do
  subject(:provider) { described_class.new }

  let(:docker_host) { create(:docker_host, ip: '10.0.0.1', start_port: 27015) }

  describe ".locations" do
    it "returns active docker hosts" do
      active_host = create(:docker_host, city: "Amsterdam", active: true)
      create(:docker_host, city: "Frankfurt", active: false, ip: "10.0.0.2")

      locations = described_class.locations
      expect(locations.keys).to eq([ active_host.id.to_s ])
      expect(locations[active_host.id.to_s][:name]).to eq("Amsterdam")
    end

    it "returns empty hash when no active hosts" do
      expect(described_class.locations).to eq({})
    end
  end

  describe "#create_server" do
    let(:cloud_server) do
      create(:cloud_server,
        cloud_provider: "remote_docker",
        cloud_callback_token: "test-token",
        port: "27015",
        cloud_location: docker_host.id.to_s)
    end
    let(:ssh_session) { instance_double(Net::SSH::Connection::Session) }

    before do
      allow(cloud_server).to receive(:cloud_ssh_public_key)
        .and_return("ssh-ed25519 AAAA test@cloud")
      allow(Net::SSH).to receive(:start).and_yield(ssh_session)
      allow(ssh_session).to receive(:exec!).and_return("container_id_abc123\n")
    end

    it "returns the provider_id with host id and container name" do
      result = provider.create_server(cloud_server)
      expect(result).to eq("#{docker_host.id}:cloud-#{cloud_server.id}")
    end

    it "SSHes to the docker host" do
      provider.create_server(cloud_server)
      expect(Net::SSH).to have_received(:start).with(docker_host.ip, nil)
    end

    it "pulls the image first" do
      provider.create_server(cloud_server)
      expect(ssh_session).to have_received(:exec!).with("docker pull serveme/tf2-cloud-server:latest")
    end

    it "runs docker with correct port mappings" do
      provider.create_server(cloud_server)
      expect(ssh_session).to have_received(:exec!).with(a_string_matching(
        /docker run -d.*-p 27015:27015\/udp -p 27015:27015\/tcp.*-p 27020:27020\/udp -p 22000:22/
      ))
    end

    it "passes callback URL using SITE_HOST" do
      provider.create_server(cloud_server)
      expect(ssh_session).to have_received(:exec!).with(a_string_matching(
        /-e CALLBACK_URL=https:\/\/#{Regexp.escape(SITE_HOST)}\/api\/cloud_servers\/#{cloud_server.id}\/ready/
      ))
    end

    it "does not include --add-host entries" do
      provider.create_server(cloud_server)
      expect(ssh_session).not_to have_received(:exec!).with(a_string_matching(/--add-host/))
    end

    it "passes CLIENT_PORT and STEAM_PORT env vars" do
      provider.create_server(cloud_server)
      expect(ssh_session).to have_received(:exec!).with(a_string_matching(/-e CLIENT_PORT=40001.*-e STEAM_PORT=30001/))
    end

    context "with non-default start_port" do
      let(:docker_host) { create(:docker_host, ip: '10.0.0.1', start_port: 27115) }
      let(:cloud_server) do
        create(:cloud_server,
          cloud_provider: "remote_docker",
          cloud_callback_token: "test-token",
          port: "27115",
          cloud_location: docker_host.id.to_s)
      end

      it "calculates server_index from the host's start_port" do
        provider.create_server(cloud_server)
        # server_index = (27115 - 27115) / 10 = 0
        # ssh_port = 22000, client_port = 40001, steam_port = 30001
        expect(ssh_session).to have_received(:exec!).with(a_string_matching(/-p 22000:22/))
        expect(ssh_session).to have_received(:exec!).with(a_string_matching(/-e CLIENT_PORT=40001/))
      end
    end
  end

  describe "#server_status" do
    let(:ssh_session) { instance_double(Net::SSH::Connection::Session) }

    before do
      allow(Net::SSH).to receive(:start).and_yield(ssh_session)
    end

    it "returns 'running' for a running container" do
      allow(ssh_session).to receive(:exec!).and_return("running\n")
      expect(provider.server_status("#{docker_host.id}:cloud-1")).to eq("running")
    end

    it "returns 'provisioning' for a created container" do
      allow(ssh_session).to receive(:exec!).and_return("created\n")
      expect(provider.server_status("#{docker_host.id}:cloud-1")).to eq("provisioning")
    end

    it "returns 'stopped' for an exited container" do
      allow(ssh_session).to receive(:exec!).and_return("exited\n")
      expect(provider.server_status("#{docker_host.id}:cloud-1")).to eq("stopped")
    end

    it "returns 'provisioning' when SSH returns nil" do
      allow(ssh_session).to receive(:exec!).and_return(nil)
      expect(provider.server_status("#{docker_host.id}:cloud-1")).to eq("provisioning")
    end
  end

  describe "#server_ip" do
    it "returns the docker host IP" do
      expect(provider.server_ip("#{docker_host.id}:cloud-1")).to eq("10.0.0.1")
    end
  end

  describe "#destroy_server" do
    let(:ssh_session) { instance_double(Net::SSH::Connection::Session) }

    before do
      allow(Net::SSH).to receive(:start).and_yield(ssh_session)
      allow(ssh_session).to receive(:exec!).and_return("cloud-1\n")
    end

    it "runs docker rm -f on the remote host" do
      provider.destroy_server("#{docker_host.id}:cloud-1")
      expect(ssh_session).to have_received(:exec!).with("docker rm -f cloud-1")
    end
  end

  describe "#estimated_provision_time" do
    it "returns about 1 minute" do
      expect(provider.estimated_provision_time).to eq("about 1 minute")
    end
  end
end
