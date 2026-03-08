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
    allow(provider).to receive(:server_ip).and_return("10.0.0.1")
    allow(provider).to receive(:provision_phases).and_return([ { name: "creating_vm", label: "Creating VM", estimated_seconds: 30 }, { name: "booting", label: "Booting", estimated_seconds: 15 }, { name: "configuring", label: "Configuring", estimated_seconds: 15 } ])
  end

  describe "#perform" do
    it "calls create_server on the provider and stores the provider_id" do
      expect(provider).to receive(:create_server).with(cloud_server).and_return("cloud-#{cloud_server.id}")
      allow(CloudServerPollWorker).to receive(:perform_in)

      described_class.new.perform(cloud_server.id)

      cloud_server.reload
      expect(cloud_server.cloud_provider_id).to eq("cloud-#{cloud_server.id}")
    end

    it "enqueues a CloudServerPollWorker" do
      allow(provider).to receive(:create_server).and_return("cloud-#{cloud_server.id}")
      expect(CloudServerPollWorker).to receive(:perform_in).with(5.seconds, cloud_server.id)

      described_class.new.perform(cloud_server.id)
    end

    it "skips creation if cloud_provider_id is already set" do
      cloud_server.update!(cloud_provider_id: "existing-123")

      expect(provider).not_to receive(:create_server)
      expect(CloudServerPollWorker).to receive(:perform_in).with(5.seconds, cloud_server.id)

      described_class.new.perform(cloud_server.id)
    end

    it "skips when cloud_status is destroyed" do
      cloud_server.update!(cloud_status: "destroyed")

      expect(provider).not_to receive(:create_server)
      expect(CloudServerPollWorker).not_to receive(:perform_in)

      described_class.new.perform(cloud_server.id)
    end

    it "marks server destroyed when reservation no longer exists" do
      cloud_server.update!(cloud_reservation_id: -1)

      expect(provider).not_to receive(:create_server)

      described_class.new.perform(cloud_server.id)

      cloud_server.reload
      expect(cloud_server.cloud_status).to eq("destroyed")
    end

    it "saves provider_id before calling server_ip so retries don't create duplicate VMs" do
      allow(provider).to receive(:create_server).and_return("vultr-abc123")
      allow(provider).to receive(:server_ip).and_raise("Transient API error")
      allow(CloudServerPollWorker).to receive(:perform_in)

      expect { described_class.new.perform(cloud_server.id) }.to raise_error("Transient API error")

      cloud_server.reload
      expect(cloud_server.cloud_provider_id).to eq("vultr-abc123")
    end

    it "destroys server if marked destroyed during provisioning" do
      provider_id = "cloud-#{cloud_server.id}"
      call_count = 0
      allow(provider).to receive(:create_server) do |_cs|
        call_count += 1
        # Simulate destroy worker marking status as destroyed during provisioning
        cloud_server.update_column(:cloud_status, "destroyed")
        provider_id
      end

      expect(provider).to receive(:destroy_server).with(provider_id)
      expect(CloudServerPollWorker).not_to receive(:perform_in)

      described_class.new.perform(cloud_server.id)
    end
  end
end
