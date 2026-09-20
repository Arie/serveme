# typed: false
# frozen_string_literal: true

require "spec_helper"

describe StockMapSyncWorker do
  let(:worker) { described_class.new }
  let(:redis) { instance_double(Redis) }
  let(:sync) { instance_double(StockMapSync, call: { uploaded: 0, verified: 0, failed: [] }) }

  before do
    stub_const("SITE_HOST", "serveme.tf")
    allow(Sidekiq).to receive(:redis).and_yield(redis)
    allow(redis).to receive(:set).and_return(true)
    allow(redis).to receive(:del)
    allow(StockMapSync).to receive(:new).and_return(sync)
  end

  describe "#perform" do
    it "syncs the stock maps" do
      worker.perform(9_999_999)

      expect(sync).to have_received(:call)
    end

    it "syncs when triggered manually without a version" do
      worker.perform

      expect(sync).to have_received(:call)
    end

    it "runs only once per TF2 version" do
      allow(redis).to receive(:set).with("stock_map_sync:9999999", anything, hash_including(nx: true)).and_return(false)

      worker.perform(9_999_999)

      expect(sync).not_to have_received(:call)
    end

    it "frees the version lock when the sync fails, so the next trigger retries" do
      allow(sync).to receive(:call).and_raise("depot downloader exploded")

      expect { worker.perform(9_999_999) }.to raise_error("depot downloader exploded")
      expect(redis).to have_received(:del).with("stock_map_sync:9999999")
    end

    context "when the sync could not sync every map" do
      before { allow(sync).to receive(:call).and_return({ uploaded: 1, verified: 0, failed: [ "cp_badlands: sha1 mismatch" ] }) }

      it "fails the job, so Sidekiq retries instead of leaving fastdl stale" do
        expect { worker.perform(9_999_999) }.to raise_error(/cp_badlands/)
      end

      it "frees the version lock for that retry" do
        expect { worker.perform(9_999_999) }.to raise_error(/cp_badlands/)
        expect(redis).to have_received(:del).with("stock_map_sync:9999999")
      end
    end

    it "retries a few times before giving up" do
      expect(described_class.sidekiq_options["retry"]).to be > 0
    end

    it "frees the version lock when a deploy stops the job mid-run" do
      allow(sync).to receive(:call).and_raise(Sidekiq::Shutdown)

      expect { worker.perform(9_999_999) }.to raise_error(Sidekiq::Shutdown)
      expect(redis).to have_received(:del).with("stock_map_sync:9999999")
    end

    context "outside the EU region" do
      before { stub_const("SITE_HOST", "na.serveme.tf") }

      it "does nothing, because fastdl is served from the EU bucket" do
        worker.perform(9_999_999)

        expect(sync).not_to have_received(:call)
      end
    end
  end
end
