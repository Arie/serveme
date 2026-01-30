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
end
