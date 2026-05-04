# typed: false
# frozen_string_literal: true

require "spec_helper"

describe NightlyCloudImageBuildWorker do
  describe "#perform" do
    it "creates a CloudImageBuild with force_pull and enqueues the build worker" do
      Rails.cache.write("latest_server_version", "1234567")
      expect(CloudImageBuildWorker).to receive(:perform_async).with(kind_of(Integer))

      expect { described_class.new.perform }.to change(CloudImageBuild, :count).by(1)

      build = CloudImageBuild.last
      expect(build.version).to eq("1234567")
      expect(build.force_pull).to eq(true)
      expect(build.triggered_by_user_id).to be_nil
      expect(build.status).to eq("queued")
    end

    it "does nothing when no cached version is present" do
      Rails.cache.delete("latest_server_version")
      expect(CloudImageBuildWorker).not_to receive(:perform_async)

      expect { described_class.new.perform }.not_to change(CloudImageBuild, :count)
    end
  end
end
