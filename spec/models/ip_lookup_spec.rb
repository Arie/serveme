# typed: false
# frozen_string_literal: true

require "spec_helper"

describe IpLookup do
  describe "validations" do
    it "requires ip to be present" do
      lookup = described_class.new(ip: nil)
      expect(lookup).not_to be_valid
      expect(lookup.errors[:ip]).to include("can't be blank")
    end

    it "requires ip to be unique" do
      described_class.create!(ip: "1.2.3.4")
      duplicate = described_class.new(ip: "1.2.3.4")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:ip]).to include("has already been taken")
    end
  end

  describe ".cached?" do
    it "returns true when IP exists" do
      expect(described_class.cached?("1.2.3.4")).to be false

      described_class.create!(ip: "1.2.3.4")
      expect(described_class.cached?("1.2.3.4")).to be true
    end
  end

  describe ".find_cached" do
    it "returns the lookup when found" do
      expect(described_class.find_cached("1.2.3.4")).to be_nil

      lookup = described_class.create!(ip: "1.2.3.4", fraud_score: 75)
      expect(described_class.find_cached("1.2.3.4")).to eq(lookup)
    end
  end

  describe ".residential_proxies" do
    it "returns only residential proxies" do
      residential = described_class.create!(ip: "1.1.1.1", is_residential_proxy: true)
      described_class.create!(ip: "2.2.2.2", is_residential_proxy: false)
      described_class.create!(ip: "3.3.3.3", is_residential_proxy: false)

      expect(described_class.residential_proxies).to eq([ residential ])
    end
  end

  describe "default values" do
    it "sets is_proxy and is_residential_proxy to false by default" do
      lookup = described_class.create!(ip: "1.2.3.4")
      expect(lookup.is_proxy).to be false
      expect(lookup.is_residential_proxy).to be false
    end
  end

  describe "cross-region sync" do
    describe "after_create_commit callback" do
      it "enqueues IpLookupSyncWorker after create" do
        expect(IpLookupSyncWorker).to receive(:perform_async).with(kind_of(Integer))
        described_class.create!(ip: "5.5.5.5")
      end

      it "does not enqueue worker when synced_from_region is set" do
        expect(IpLookupSyncWorker).not_to receive(:perform_async)

        lookup = described_class.new(ip: "6.6.6.6")
        lookup.synced_from_region = true
        lookup.save!
      end
    end

    describe ".upsert_from_sync" do
      it "creates a new record when IP does not exist" do
        expect(IpLookupSyncWorker).not_to receive(:perform_async)

        result = described_class.upsert_from_sync(
          ip: "7.7.7.7",
          is_proxy: true,
          is_residential_proxy: true,
          fraud_score: 100,
          isp: "Test ISP",
          country_code: "US"
        )

        expect(result).to be_persisted
        expect(result.ip).to eq("7.7.7.7")
        expect(result.is_proxy).to be true
        expect(result.is_residential_proxy).to be true
        expect(result.fraud_score).to eq(100)
        expect(result.isp).to eq("Test ISP")
        expect(result.country_code).to eq("US")
      end

      it "updates an existing record when IP already exists" do
        existing = described_class.create!(ip: "8.8.8.8", fraud_score: 50, isp: "Old ISP")

        result = described_class.upsert_from_sync(
          ip: "8.8.8.8",
          fraud_score: 100,
          isp: "New ISP"
        )

        expect(result.id).to eq(existing.id)
        expect(result.fraud_score).to eq(100)
        expect(result.isp).to eq("New ISP")
      end

      it "only permits allowed attributes" do
        result = described_class.upsert_from_sync(
          ip: "9.9.9.9",
          fraud_score: 75,
          created_at: 1.year.ago,
          id: 999999
        )

        expect(result.id).not_to eq(999999)
        expect(result.created_at).to be > 1.day.ago
      end

      it "handles string keys in attributes" do
        result = described_class.upsert_from_sync(
          "ip" => "10.10.10.10",
          "fraud_score" => 80
        )

        expect(result.ip).to eq("10.10.10.10")
        expect(result.fraud_score).to eq(80)
      end
    end
  end
end
