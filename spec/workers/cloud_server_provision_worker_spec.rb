# typed: false
# frozen_string_literal: true

require "spec_helper"

describe CloudServerProvisionWorker do
  let(:cloud_server) { create(:cloud_server, cloud_provider: "docker", cloud_status: "provisioning", cloud_provider_id: nil) }
  let(:provider) { instance_double(CloudProvider::Docker) }

  before do
    allow(CloudProvider).to receive(:for).with("docker").and_return(provider)
    allow(provider).to receive(:estimated_provision_time).and_return("less than a minute")
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
  end
end
