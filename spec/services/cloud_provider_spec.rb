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

    it "hides Hetzner and Vultr in EU and NA" do
      stub_const("CloudProvider::SITE_REGION", "EU")
      result = described_class.grouped_locations
      all_values = result.values.flatten(1).map(&:last)
      expect(all_values).not_to include(a_string_starting_with("hetzner:"))
      expect(all_values).not_to include(a_string_starting_with("vultr:"))
    end

    context "when SITE_REGION is AU" do
      subject(:grouped) { described_class.grouped_locations }

      before { stub_const("CloudProvider::SITE_REGION", "AU") }

      it "groups locations by country" do
        expect(grouped.keys).to include("Australia")
      end

      it "includes Vultr locations" do
        australia_values = grouped["Australia"].map(&:last)
        expect(australia_values).to include("vultr:mel")
      end

      it "formats labels as 'City (Provider)'" do
        mel_entry = grouped["Australia"].find { |_, v| v == "vultr:mel" }
        expect(mel_entry.first).to eq("Melbourne (Vultr)")
      end
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
    it "returns 5 phases for Base provider" do
      phases = CloudProvider::Base.new.provision_phases
      expect(phases.length).to eq(5)
      phases.each do |phase|
        expect(phase.keys).to match_array(%i[key label icon seconds])
      end
    end

    it "returns creating_vm, booting, configuring, booting_tf2, starting_tf2 phases" do
      keys = CloudProvider::Base.new.provision_phases.map { |p| p[:key] }
      expect(keys).to eq(%w[creating_vm booting configuring booting_tf2 starting_tf2])
    end

    it "sums to 175 for Hetzner" do
      phases = CloudProvider::Hetzner.new.provision_phases
      expect(phases.sum { |p| p[:seconds] }).to eq(175)
    end

    it "sums to 245 for Vultr" do
      phases = CloudProvider::Vultr.new.provision_phases
      expect(phases.sum { |p| p[:seconds] }).to eq(245)
    end
  end

  describe "estimated_provision_seconds" do
    it "returns 240 for Base provider" do
      expect(CloudProvider::Base.new.estimated_provision_seconds).to eq(240)
    end

    it "returns 175 for Hetzner provider" do
      expect(CloudProvider::Hetzner.new.estimated_provision_seconds).to eq(175)
    end

    it "computes from provision_phases" do
      provider = CloudProvider::Base.new
      expected = provider.provision_phases.sum { |p| p[:seconds] }
      expect(provider.estimated_provision_seconds).to eq(expected)
    end
  end
end
