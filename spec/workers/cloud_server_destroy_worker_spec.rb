# typed: false
# frozen_string_literal: true

require "spec_helper"

describe CloudServerDestroyWorker do
  let(:cloud_server) { create(:cloud_server, cloud_provider: "docker", cloud_status: "ready", cloud_provider_id: "cloud-123") }
  let(:provider) { instance_double(CloudProvider::Docker) }

  before do
    allow(CloudProvider).to receive(:for).with("docker").and_return(provider)
    allow(provider).to receive(:cloud_server_name).and_return("serveme-eu-#{cloud_server.cloud_reservation_id}")
    allow(provider).to receive(:destroy_servers_by_label).and_return(0)
  end

  describe "#perform" do
    it "destroys the server via the provider and updates status" do
      expect(provider).to receive(:destroy_server).with("cloud-123")

      described_class.new.perform(cloud_server.id)

      cloud_server.reload
      expect(cloud_server.cloud_status).to eq("destroyed")
      expect(cloud_server.cloud_destroyed_at).to be_present
    end

    it "calls destroy_servers_by_label as safety net" do
      allow(provider).to receive(:destroy_server)
      expect(provider).to receive(:destroy_servers_by_label).with("serveme-eu-#{cloud_server.cloud_reservation_id}")

      described_class.new.perform(cloud_server.id)
    end

    it "skips when already destroyed and no provider_id" do
      cloud_server.update!(cloud_status: "destroyed", cloud_provider_id: nil)

      expect(provider).not_to receive(:destroy_server)

      described_class.new.perform(cloud_server.id)
    end

    it "still destroys container when already marked destroyed but provider_id is present" do
      cloud_server.update!(cloud_status: "destroyed", cloud_provider_id: "cloud-123")

      expect(provider).to receive(:destroy_server).with("cloud-123")

      described_class.new.perform(cloud_server.id)
    end

    context "when provisioning and provider_id is blank" do
      before do
        cloud_server.update!(cloud_provider_id: nil, cloud_status: "provisioning", cloud_created_at: Time.current)
      end

      it "marks as destroyed and re-enqueues as safety net" do
        expect(CloudServerDestroyWorker).to receive(:perform_in).with(30.seconds, cloud_server.id)

        described_class.new.perform(cloud_server.id)

        cloud_server.reload
        expect(cloud_server.cloud_status).to eq("destroyed")
        expect(cloud_server.active).to be false
      end

      it "gives up after MAX_PROVISION_WAIT" do
        cloud_server.update!(cloud_created_at: 20.minutes.ago)

        expect(CloudServerDestroyWorker).not_to receive(:perform_in)

        described_class.new.perform(cloud_server.id)

        cloud_server.reload
        expect(cloud_server.cloud_status).to eq("destroyed")
      end
    end
  end
end
