# typed: false
# frozen_string_literal: true

require "spec_helper"

describe CloudSnapshotWorker do
  let(:worker) { described_class.new }
  let(:provider) { instance_double(CloudProvider::Hetzner) }
  let(:redis) { instance_double(Redis) }

  before do
    allow(Sidekiq).to receive(:redis).and_yield(redis)
    allow(redis).to receive(:set).and_return(true)
    allow(redis).to receive(:del)
    allow(CloudProvider).to receive(:for).with("hetzner").and_return(provider)
    allow(Rails.application.credentials).to receive(:dig).with(:cloud_servers, :ssh_private_key).and_return("fake-key")
  end

  describe "#perform" do
    it "skips if lock cannot be acquired" do
      allow(redis).to receive(:set).and_return(false)

      expect(provider).not_to receive(:create_snapshot_server)

      worker.perform("hetzner", "fsn1")
    end

    it "releases the lock after completion" do
      allow(redis).to receive(:set).and_return(false)
      expect(redis).to receive(:del).with("cloud_snapshot")

      worker.perform("hetzner", "fsn1")
    end
  end
end
