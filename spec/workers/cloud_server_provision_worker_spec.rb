# typed: false
# frozen_string_literal: true

require "spec_helper"

describe CloudServerProvisionWorker do
  let(:cloud_server) { create(:cloud_server, cloud_provider: "docker", cloud_status: "provisioning", cloud_provider_id: nil) }
  let(:reservation) { create(:reservation, server: cloud_server) }
  let(:provider) { instance_double(CloudProvider::Docker) }

  before do
    cloud_server.update!(cloud_reservation_id: reservation.id)
    allow(CloudProvider).to receive(:for).with("docker").and_return(provider)
    allow(provider).to receive(:estimated_provision_time).and_return("less than a minute")
    allow(provider).to receive(:pending_command?).and_return(false)
    allow(provider).to receive(:server_ip).and_return("10.0.0.1")
    allow(provider).to receive(:provision_phases).and_return([ { name: "creating_vm", label: "Creating VM", estimated_seconds: 30 }, { name: "booting", label: "Booting", estimated_seconds: 15 }, { name: "configuring", label: "Configuring", estimated_seconds: 15 } ])
    allow($lock).to receive(:synchronize).and_yield
  end

  describe "#perform" do
    it "goes through find_or_create_server so a retry adopts rather than duplicates" do
      expect(provider).to receive(:find_or_create_server).with(cloud_server).and_return("cloud-#{cloud_server.id}")
      allow(CloudServerPollWorker).to receive(:perform_in)

      described_class.new.perform(cloud_server.id)

      cloud_server.reload
      expect(cloud_server.cloud_provider_id).to eq("cloud-#{cloud_server.id}")
    end

    it "enqueues a CloudServerPollWorker" do
      allow(provider).to receive(:find_or_create_server).and_return("cloud-#{cloud_server.id}")
      expect(CloudServerPollWorker).to receive(:perform_in).with(5.seconds, cloud_server.id)

      described_class.new.perform(cloud_server.id)
    end

    it "skips creation if cloud_provider_id is already set" do
      cloud_server.update!(cloud_provider_id: "existing-123")

      expect(provider).not_to receive(:find_or_create_server)
      expect(CloudServerPollWorker).to receive(:perform_in).with(5.seconds, cloud_server.id)

      described_class.new.perform(cloud_server.id)
    end

    it "skips when cloud_status is destroyed" do
      cloud_server.update!(cloud_status: "destroyed")

      expect(provider).not_to receive(:find_or_create_server)
      expect(CloudServerPollWorker).not_to receive(:perform_in)

      described_class.new.perform(cloud_server.id)
    end

    it "marks server destroyed when reservation no longer exists" do
      cloud_server.update!(cloud_reservation_id: -1)

      expect(provider).not_to receive(:find_or_create_server)

      described_class.new.perform(cloud_server.id)

      cloud_server.reload
      expect(cloud_server.cloud_status).to eq("destroyed")
    end

    it "saves provider_id before calling server_ip so retries don't create duplicate VMs" do
      allow(provider).to receive(:find_or_create_server).and_return("vultr-abc123")
      allow(provider).to receive(:server_ip).and_raise("Transient API error")
      allow(CloudServerPollWorker).to receive(:perform_in)

      expect { described_class.new.perform(cloud_server.id) }.to raise_error("Transient API error")

      cloud_server.reload
      expect(cloud_server.cloud_provider_id).to eq("vultr-abc123")
    end

    it "acquires a lock to prevent duplicate provisioning" do
      allow(provider).to receive(:find_or_create_server).and_return("cloud-#{cloud_server.id}")
      allow(CloudServerPollWorker).to receive(:perform_in)

      expect($lock).to receive(:synchronize).with("cloud-provision-#{cloud_server.id}", retries: 1, expiry: 5.minutes).and_yield

      described_class.new.perform(cloud_server.id)
    end

    it "skips when lock is already held" do
      allow($lock).to receive(:synchronize).and_raise(RemoteLock::Error)

      expect(provider).not_to receive(:find_or_create_server)

      described_class.new.perform(cloud_server.id)
    end

    it "destroys server if marked destroyed during provisioning" do
      provider_id = "cloud-#{cloud_server.id}"
      call_count = 0
      allow(provider).to receive(:find_or_create_server) do |_cs|
        call_count += 1
        # Simulate destroy worker marking status as destroyed during provisioning
        cloud_server.update_column(:cloud_status, "destroyed")
        provider_id
      end

      expect(provider).to receive(:destroy_server).with(provider_id)
      expect(CloudServerPollWorker).not_to receive(:perform_in)

      described_class.new.perform(cloud_server.id)
    end

    it "tells the user where the server is being created, by name" do
      allow(provider).to receive(:find_or_create_server).and_return("cloud-#{cloud_server.id}")
      allow(CloudServerPollWorker).to receive(:perform_in)

      described_class.new.perform(cloud_server.id)

      expect(reservation.reservation_statuses.map(&:status)).to include(
        "Creating server in #{cloud_server.location.name}, this takes less than a minute"
      )
    end

    context "on a remote docker host" do
      let(:docker_host) { create(:docker_host) }
      let(:cloud_server) do
        create(:cloud_server, cloud_provider: "remote_docker", cloud_location: docker_host.id.to_s,
                              location: docker_host.location, cloud_status: "provisioning", cloud_provider_id: nil)
      end
      let(:provider) { instance_double(CloudProvider::RemoteDocker) }

      before do
        allow(CloudProvider).to receive(:for).with("remote_docker").and_return(provider)
      end

      it "names the city instead of leaking the docker host id and the provider name" do
        allow(provider).to receive(:find_or_create_server).and_return("#{docker_host.id}:container")
        allow(CloudServerPollWorker).to receive(:perform_in)

        described_class.new.perform(cloud_server.id)

        statuses = reservation.reservation_statuses.map(&:status)
        expect(statuses).to include(
          "Creating server in #{docker_host.city}, this takes less than a minute"
        )
        expect(statuses).not_to include(a_string_matching(/remote_docker|in #{docker_host.id},/))
      end
    end
  end
end
