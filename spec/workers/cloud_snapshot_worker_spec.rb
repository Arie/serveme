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

    context "when the lock is acquired" do
      before do
        allow(CloudServer).to receive(:new).and_return(double(cloud_ssh_key_file: "/tmp/cloud key"))
        allow(provider).to receive(:create_snapshot_server).and_return([ "srv-1", "1.2.3.4" ])
        allow(provider).to receive(:destroy_server)
        allow(provider).to receive(:halt_server)
        allow(provider).to receive(:create_snapshot).and_return("snap-2")
        allow(provider).to receive(:wait_for_snapshot)
        allow(provider).to receive(:delete_old_snapshots).and_return(1)
        allow(provider).to receive(:snapshot_credential_key).and_return("hetzner_snapshot_id")
        allow(worker).to receive(:sleep)
      end

      it "builds a snapshot from a temporary VM once the image is pulled" do
        allow(worker).to receive(:`).and_return("", "READY\n")

        expect(provider).to receive(:create_snapshot_server).with("fsn1", include("docker pull serveme/tf2-cloud-server:latest")).ordered.and_return([ "srv-1", "1.2.3.4" ])
        expect(provider).to receive(:halt_server).with("srv-1").ordered
        expect(provider).to receive(:create_snapshot).with("srv-1", match(/\Aserveme-cloud-\d{8}-\d{4}\z/)).ordered.and_return("snap-2")
        expect(provider).to receive(:wait_for_snapshot).with("snap-2").ordered
        expect(provider).to receive(:destroy_server).with("srv-1").ordered
        expect(provider).to receive(:delete_old_snapshots).with("snap-2").ordered.and_return(1)

        worker.perform("hetzner", "fsn1")

        expect(worker).to have_received(:`).with(include("-i /tmp/cloud\\ key root@1.2.3.4")).twice
        expect(redis).to have_received(:del).with("cloud_snapshot")
      end

      it "destroys the VM without snapshotting when the image never becomes ready" do
        allow(worker).to receive(:`).and_return("")

        worker.perform("hetzner", "fsn1")

        expect(worker).to have_received(:`).exactly(180).times
        expect(provider).to have_received(:destroy_server).with("srv-1")
        expect(provider).not_to have_received(:halt_server)
        expect(provider).not_to have_received(:create_snapshot)
        expect(redis).to have_received(:del).with("cloud_snapshot")
      end

      it "releases the lock when snapshotting fails" do
        allow(worker).to receive(:`).and_return("READY")
        allow(provider).to receive(:create_snapshot).and_raise(RuntimeError, "api down")

        expect { worker.perform("hetzner", "fsn1") }.to raise_error(RuntimeError, "api down")
        expect(redis).to have_received(:del).with("cloud_snapshot")
      end
    end
  end
end
