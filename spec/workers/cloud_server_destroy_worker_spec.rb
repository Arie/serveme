# typed: false
# frozen_string_literal: true

require "spec_helper"

describe CloudServerDestroyWorker do
  let(:cloud_server) { create(:cloud_server, cloud_provider: "docker", cloud_status: "ready", cloud_provider_id: "cloud-123") }
  let(:provider) { instance_double(CloudProvider::Docker) }

  before do
    allow(CloudProvider).to receive(:for).with("docker").and_return(provider)
  end

  describe "#perform" do
    it "destroys the server via the provider and updates status" do
      expect(provider).to receive(:destroy_server).with("cloud-123")

      described_class.new.perform(cloud_server.id)

      cloud_server.reload
      expect(cloud_server.cloud_status).to eq("destroyed")
      expect(cloud_server.cloud_destroyed_at).to be_present
    end

    it "skips if server is already destroyed" do
      cloud_server.update!(cloud_status: "destroyed")

      expect(provider).not_to receive(:destroy_server)

      described_class.new.perform(cloud_server.id)
    end

    it "skips if provider_id is blank" do
      cloud_server.update!(cloud_provider_id: nil)

      expect(provider).not_to receive(:destroy_server)

      described_class.new.perform(cloud_server.id)
    end
  end
end
