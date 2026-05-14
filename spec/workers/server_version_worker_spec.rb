# typed: false
# frozen_string_literal: true

require "spec_helper"

describe ServerVersionWorker do
  let(:worker) { described_class.new }

  before do
    allow(ServerUpdateWorker).to receive(:perform_async)
    allow(CloudImageBuildWorker).to receive(:perform_async)
    allow(Rails.cache).to receive(:read).and_call_original
  end

  describe "#perform" do
    context "when the version has changed" do
      before do
        allow(Server).to receive(:fetch_latest_version).and_return(9_999_999)
        allow(Rails.cache).to receive(:read).with("latest_server_version").and_return(9_999_998)
      end

      it "enqueues ServerUpdateWorker with the version" do
        worker.perform
        expect(ServerUpdateWorker).to have_received(:perform_async).with(9_999_999)
      end

      context "on the EU region" do
        before { stub_const("SITE_HOST", "serveme.tf") }

        it "creates a CloudImageBuild record for the new version" do
          expect { worker.perform }.to change(CloudImageBuild, :count).by(1)
          expect(CloudImageBuild.last.version).to eq("9999999")
        end

        it "enqueues CloudImageBuildWorker with the build id, not the raw version" do
          worker.perform
          build = CloudImageBuild.last
          expect(CloudImageBuildWorker).to have_received(:perform_async).with(build.id)
        end
      end

      context "on a non-EU region" do
        before { stub_const("SITE_HOST", "na.serveme.tf") }

        it "does not create a CloudImageBuild record" do
          expect { worker.perform }.not_to change(CloudImageBuild, :count)
        end

        it "does not enqueue CloudImageBuildWorker" do
          worker.perform
          expect(CloudImageBuildWorker).not_to have_received(:perform_async)
        end
      end
    end

    context "when the version is unchanged" do
      before do
        stub_const("SITE_HOST", "serveme.tf")
        allow(Server).to receive(:fetch_latest_version).and_return(9_999_999)
        allow(Rails.cache).to receive(:read).with("latest_server_version").and_return(9_999_999)
      end

      it "does not create a CloudImageBuild" do
        expect { worker.perform }.not_to change(CloudImageBuild, :count)
      end

      it "does not enqueue CloudImageBuildWorker" do
        worker.perform
        expect(CloudImageBuildWorker).not_to have_received(:perform_async)
      end
    end

    context "when the latest version cannot be fetched" do
      before do
        allow(Server).to receive(:fetch_latest_version).and_return(nil)
      end

      it "does nothing" do
        expect { worker.perform }.not_to change(CloudImageBuild, :count)
        expect(ServerUpdateWorker).not_to have_received(:perform_async)
      end
    end
  end
end
