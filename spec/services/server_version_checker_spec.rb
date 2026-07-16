# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe ServerVersionChecker do
  describe ".fetch_latest_version" do
    context "in a non-test environment" do
      before { allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production")) }

      define_method(:stub_steam) do |success:, body:|
        allow(Faraday).to receive(:new).and_return(
          instance_double(Faraday::Connection, get: instance_double(Faraday::Response, success?: success, body: body.to_json))
        )
      end

      it "returns the required_version when Steam answers normally" do
        stub_steam(success: true, body: { "response" => { "required_version" => 10_822_003 } })
        expect(described_class.fetch_latest_version).to eq(10_822_003)
      end

      it "returns nil (not 0) when required_version is missing" do
        stub_steam(success: true, body: { "response" => { "success" => false } })
        expect(described_class.fetch_latest_version).to be_nil
      end

      it "returns nil when the Steam request is unsuccessful" do
        stub_steam(success: false, body: {})
        expect(described_class.fetch_latest_version).to be_nil
      end

      it "returns nil on a timeout" do
        allow(Faraday).to receive(:new).and_raise(Faraday::TimeoutError)
        expect(described_class.fetch_latest_version).to be_nil
      end
    end

    it "short-circuits to a sentinel high version in the test environment" do
      expect(described_class.fetch_latest_version).to eq(100_000_000)
    end
  end

  describe ".latest_version" do
    before { Rails.cache.delete("latest_server_version") }

    it "returns the fetched version" do
      allow(described_class).to receive(:fetch_latest_version).and_return(12_345)
      expect(described_class.latest_version).to eq(12_345)
    end
  end

  describe "#current" do
    it "parses the network patch version from the rcon version response" do
      server = build_stubbed(:server)
      allow(server).to receive(:rcon_exec).with("version").and_return("Network PatchVersion: 5257083\nfoo bar")
      expect(described_class.new(server).current).to eq(5_257_083)
    end

    it "is nil when the version cannot be parsed" do
      server = build_stubbed(:server)
      allow(server).to receive(:rcon_exec).with("version").and_return("")
      expect(described_class.new(server).current).to be_nil
    end
  end

  describe "#outdated?" do
    let(:server) { build_stubbed(:server) }

    it "is false for team comtress servers regardless of version" do
      allow(server).to receive(:team_comtress_server?).and_return(true)
      expect(described_class.new(server)).not_to be_outdated
    end

    it "is true when the server version is behind the latest" do
      allow(server).to receive(:team_comtress_server?).and_return(false)
      allow(server).to receive(:rcon_exec).with("version").and_return("Network PatchVersion: 5257083")
      allow(described_class).to receive(:latest_version).and_return(100_000_000)
      expect(described_class.new(server)).to be_outdated
    end

    it "is false when the server is on the latest version" do
      allow(server).to receive(:team_comtress_server?).and_return(false)
      allow(server).to receive(:rcon_exec).with("version").and_return("Network PatchVersion: 100000000")
      allow(described_class).to receive(:latest_version).and_return(100_000_000)
      expect(described_class.new(server)).not_to be_outdated
    end
  end
end
