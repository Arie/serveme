# typed: false
# frozen_string_literal: true

require "spec_helper"

describe CloudServerOrphanCleanupWorker do
  let(:vultr_provider) { instance_double(CloudProvider::Vultr) }
  let(:hetzner_provider) { instance_double(CloudProvider::Hetzner) }

  before do
    allow(CloudProvider).to receive(:for).with("vultr").and_return(vultr_provider)
    allow(CloudProvider).to receive(:for).with("hetzner").and_return(hetzner_provider)
    allow(vultr_provider).to receive(:list_servers).and_return([])
    allow(hetzner_provider).to receive(:list_servers).and_return([])
  end

  describe "#perform" do
    it "destroys orphan VMs with no matching active cloud server" do
      allow(vultr_provider).to receive(:list_servers).and_return([
        { provider_id: "orphan-123", label: "serveme-localhost-99999", created_at: 1.hour.ago }
      ])

      expect(vultr_provider).to receive(:destroy_server).with("orphan-123")

      described_class.new.perform
    end

    it "skips VMs that match an active cloud server" do
      cloud_server = create(:cloud_server, cloud_provider: "vultr", cloud_status: "ready", cloud_provider_id: "active-456")

      allow(vultr_provider).to receive(:list_servers).and_return([
        { provider_id: "active-456", label: "serveme-localhost-#{cloud_server.cloud_reservation_id}", created_at: 1.hour.ago }
      ])

      expect(vultr_provider).not_to receive(:destroy_server)

      described_class.new.perform
    end

    it "skips VMs with labels not matching the region prefix" do
      allow(vultr_provider).to receive(:list_servers).and_return([
        { provider_id: "other-789", label: "serveme-na-12345", created_at: 1.hour.ago }
      ])

      expect(vultr_provider).not_to receive(:destroy_server)

      described_class.new.perform
    end

    it "skips VMs younger than MIN_AGE" do
      allow(vultr_provider).to receive(:list_servers).and_return([
        { provider_id: "new-111", label: "serveme-localhost-99999", created_at: 5.minutes.ago }
      ])

      expect(vultr_provider).not_to receive(:destroy_server)

      described_class.new.perform
    end

    it "handles API errors gracefully" do
      allow(vultr_provider).to receive(:list_servers).and_raise("API timeout")

      expect { described_class.new.perform }.not_to raise_error
    end

    it "checks both vultr and hetzner providers" do
      expect(vultr_provider).to receive(:list_servers).and_return([])
      expect(hetzner_provider).to receive(:list_servers).and_return([])

      described_class.new.perform
    end
  end
end
