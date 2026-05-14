# typed: false
# frozen_string_literal: true

require "spec_helper"

describe DockerImageReadiness do
  describe ".recorded_version" do
    it "returns the recorded version as an integer" do
      SiteSetting.set(described_class::VERSION_SETTING_KEY, "9876543")
      expect(described_class.recorded_version).to eq(9_876_543)
    end

    it "returns nil when no version has been recorded" do
      SiteSetting.set(described_class::VERSION_SETTING_KEY, nil)
      expect(described_class.recorded_version).to be_nil
    end
  end

  describe ".stale?" do
    it "is false (fail-open) when no version has been recorded" do
      SiteSetting.set(described_class::VERSION_SETTING_KEY, nil)
      allow(Server).to receive(:latest_version).and_return(9_999_999)
      expect(described_class.stale?).to be false
    end

    it "is false (fail-open) when the latest TF2 version is unknown" do
      SiteSetting.set(described_class::VERSION_SETTING_KEY, "9876543")
      allow(Server).to receive(:latest_version).and_return(nil)
      expect(described_class.stale?).to be false
    end

    it "is false when the recorded version matches the latest TF2 version" do
      SiteSetting.set(described_class::VERSION_SETTING_KEY, "9876543")
      allow(Server).to receive(:latest_version).and_return(9_876_543)
      expect(described_class.stale?).to be false
    end

    it "is false when the recorded version is newer than the latest TF2 version" do
      SiteSetting.set(described_class::VERSION_SETTING_KEY, "9876544")
      allow(Server).to receive(:latest_version).and_return(9_876_543)
      expect(described_class.stale?).to be false
    end

    it "is true when the recorded version is behind the latest TF2 version" do
      SiteSetting.set(described_class::VERSION_SETTING_KEY, "9876543")
      allow(Server).to receive(:latest_version).and_return(9_999_999)
      expect(described_class.stale?).to be true
    end
  end
end
