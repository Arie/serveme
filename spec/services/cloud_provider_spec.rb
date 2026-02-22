# typed: false

require "spec_helper"

RSpec.describe CloudProvider do
  describe ".for" do
    it "returns a Hetzner provider for 'hetzner'" do
      expect(described_class.for("hetzner")).to be_a(CloudProvider::Hetzner)
    end

    it "returns a Vultr provider for 'vultr'" do
      expect(described_class.for("vultr")).to be_a(CloudProvider::Vultr)
    end

    it "returns a Docker provider for 'docker'" do
      expect(described_class.for("docker")).to be_a(CloudProvider::Docker)
    end

    it "raises ArgumentError for unknown providers" do
      expect { described_class.for("unknown") }.to raise_error(ArgumentError, "Unknown cloud provider: unknown")
    end
  end

  describe ".grouped_locations" do
    subject(:grouped) { described_class.grouped_locations }

    it "groups locations by region" do
      expect(grouped.keys).to eq(%w[EU NA AU SEA])
    end

    it "includes Hetzner locations" do
      eu_values = grouped["EU"].map(&:last)
      expect(eu_values).to include("hetzner:fsn1")
    end

    it "includes Vultr locations" do
      na_values = grouped["NA"].map(&:last)
      expect(na_values).to include("vultr:ewr")
    end

    it "formats labels as 'City, Country (Provider)'" do
      fsn1_entry = grouped["EU"].find { |_, v| v == "hetzner:fsn1" }
      expect(fsn1_entry.first).to eq("Falkenstein, Germany (Hetzner)")
    end

    it "sorts locations alphabetically within each region" do
      eu_labels = grouped["EU"].map(&:first)
      expect(eu_labels).to eq(eu_labels.sort)
    end
  end
end
