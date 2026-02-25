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

    it "groups locations by country" do
      expect(grouped.keys).to include("Germany", "Finland")
    end

    it "includes Hetzner locations" do
      germany_values = grouped["Germany"].map(&:last)
      expect(germany_values).to include("hetzner:fsn1")
    end

    it "includes Vultr locations" do
      netherlands_values = grouped["Netherlands"].map(&:last)
      expect(netherlands_values).to include("vultr:ams")
    end

    it "formats labels as 'City (Provider)'" do
      fsn1_entry = grouped["Germany"].find { |_, v| v == "hetzner:fsn1" }
      expect(fsn1_entry.first).to eq("Falkenstein (Hetzner)")
    end

    it "sorts locations alphabetically within each country" do
      grouped.each_value do |locs|
        labels = locs.map(&:first)
        expect(labels).to eq(labels.sort)
      end
    end

    it "sorts countries alphabetically" do
      expect(grouped.keys).to eq(grouped.keys.sort)
    end
  end

  describe "provision_phases" do
    it "returns 3 phases for Base provider" do
      phases = CloudProvider::Base.new.provision_phases
      expect(phases.length).to eq(3)
      phases.each do |phase|
        expect(phase.keys).to match_array(%i[key label icon seconds])
      end
    end

    it "returns creating_vm, booting, configuring phases" do
      keys = CloudProvider::Base.new.provision_phases.map { |p| p[:key] }
      expect(keys).to eq(%w[creating_vm booting configuring])
    end

    it "sums to 135 for Hetzner" do
      phases = CloudProvider::Hetzner.new.provision_phases
      expect(phases.sum { |p| p[:seconds] }).to eq(135)
    end

    it "sums to 192 for Vultr" do
      phases = CloudProvider::Vultr.new.provision_phases
      expect(phases.sum { |p| p[:seconds] }).to eq(192)
    end
  end

  describe "estimated_provision_seconds" do
    it "returns 240 for Base provider" do
      expect(CloudProvider::Base.new.estimated_provision_seconds).to eq(240)
    end

    it "returns 135 for Hetzner provider" do
      expect(CloudProvider::Hetzner.new.estimated_provision_seconds).to eq(135)
    end

    it "computes from provision_phases" do
      provider = CloudProvider::Base.new
      expected = provider.provision_phases.sum { |p| p[:seconds] }
      expect(provider.estimated_provision_seconds).to eq(expected)
    end
  end
end
