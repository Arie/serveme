# typed: false
# frozen_string_literal: true

require "spec_helper"

describe CloudServerPollWorker do
  let(:cloud_server) { create(:cloud_server, cloud_provider: "docker", cloud_status: "provisioning", cloud_provider_id: "cloud-123", cloud_created_at: 1.minute.ago) }
  let(:provider) { instance_double(CloudProvider::Docker) }

  before do
    allow(CloudProvider).to receive(:for).with("docker").and_return(provider)
  end

  describe "#perform" do
    it "polls the provider for status and re-enqueues" do
      allow(provider).to receive(:server_status).with("cloud-123").and_return("provisioning")
      expect(CloudServerPollWorker).to receive(:perform_in).with(5.seconds, cloud_server.id)

      described_class.new.perform(cloud_server.id)
    end

    it "updates the IP when server is running" do
      allow(provider).to receive(:server_status).with("cloud-123").and_return("running")
      allow(provider).to receive(:server_ip).with("cloud-123").and_return("5.6.7.8")
      allow(CloudServerPollWorker).to receive(:perform_in)

      described_class.new.perform(cloud_server.id)

      expect(cloud_server.reload.ip).to eq("5.6.7.8")
    end

    it "stops polling when server is ready but still updates IP" do
      cloud_server.update!(cloud_status: "ready")
      allow(provider).to receive(:server_status).with("cloud-123").and_return("running")
      allow(provider).to receive(:server_ip).with("cloud-123").and_return("5.6.7.8")

      expect(CloudServerPollWorker).not_to receive(:perform_in)

      described_class.new.perform(cloud_server.id)

      expect(cloud_server.reload.ip).to eq("5.6.7.8")
    end

    it "stops polling when server is destroyed" do
      cloud_server.update!(cloud_status: "destroyed")

      expect(CloudServerPollWorker).not_to receive(:perform_in)

      described_class.new.perform(cloud_server.id)
    end

    it "stops polling and destroys VM when server has been polling too long" do
      cloud_server.update!(cloud_created_at: 11.minutes.ago)

      expect(CloudServerPollWorker).not_to receive(:perform_in)
      expect(CloudServerDestroyWorker).to receive(:perform_async).with(cloud_server.id)

      described_class.new.perform(cloud_server.id)
    end

    it "does not poll provider when provider_id is blank" do
      cloud_server.update!(cloud_provider_id: nil)

      expect(provider).not_to receive(:server_status)

      described_class.new.perform(cloud_server.id)
    end

    it "re-schedules on transient API errors" do
      allow(provider).to receive(:server_status).and_raise(StandardError.new("connection timeout"))
      expect(CloudServerPollWorker).to receive(:perform_in).with(10.seconds, cloud_server.id)

      described_class.new.perform(cloud_server.id)
    end
  end
end
