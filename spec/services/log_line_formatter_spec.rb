# typed: false
# frozen_string_literal: true

require "spec_helper"

describe LogLineFormatter do
  describe "#format" do
    context "with a kill event" do
      let(:line) do
        'L 02/15/2013 - 00:14:52: "Aka Game<4><STEAM_0:0:5253998><Red>" killed "ser mais leve<6><STEAM_0:0:41722710><Blue>" with "scattergun" (attacker_position "896 -1290 256") (victim_position "726 -1245 297")'
      end
      let(:formatter) { described_class.new(line) }
      let(:formatted) { formatter.format }

      it "returns kill event type" do
        expect(formatted[:type]).to eq(:kill)
      end

      it "parses the timestamp" do
        expect(formatted[:timestamp]).to eq(Time.local(2013, 2, 15, 0, 14, 52))
      end

      it "extracts player information" do
        expect(formatted[:event].player.name).to eq("Aka Game")
        expect(formatted[:event].player.team).to eq("Red")
      end

      it "extracts target information" do
        expect(formatted[:event].target.name).to eq("ser mais leve")
        expect(formatted[:event].target.team).to eq("Blue")
      end

      it "extracts weapon" do
        expect(formatted[:event].weapon).to eq("scattergun")
      end

      it "removes position data from clean output" do
        expect(formatted[:clean]).not_to include("attacker_position")
        expect(formatted[:clean]).not_to include("victim_position")
      end

      it "keeps raw line intact" do
        expect(formatted[:raw]).to include("attacker_position")
      end
    end

    context "with a chat event" do
      let(:line) do
        'L 03/29/2014 - 13:15:53: "Arie - serveme.tf<3><[U:1:231702]><Red>" say "!extend"'
      end
      let(:formatter) { described_class.new(line) }
      let(:formatted) { formatter.format }

      it "returns say event type" do
        expect(formatted[:type]).to eq(:say)
      end

      it "extracts player name" do
        expect(formatted[:event].player.name).to eq("Arie - serveme.tf")
      end

      it "extracts message" do
        expect(formatted[:event].message).to eq("!extend")
      end
    end

    context "with a connect event" do
      let(:line) do
        'L 02/15/2013 - 00:13:12: "Aka Game<4><STEAM_0:0:5253998><>" connected, address "0.0.0.0:27005"'
      end
      let(:formatter) { described_class.new(line) }
      let(:formatted) { formatter.format }

      it "returns connect event type" do
        expect(formatted[:type]).to eq(:connect)
      end

      it "extracts player name" do
        expect(formatted[:event].player.name).to eq("Aka Game")
      end
    end

    context "with an unknown event" do
      let(:line) { "Some random log line that doesn't match any pattern" }
      let(:formatter) { described_class.new(line) }
      let(:formatted) { formatter.format }

      it "returns unknown event type" do
        expect(formatted[:type]).to eq(:unknown)
      end
    end
  end

  describe ".steam_id_to_community_id" do
    it "converts Steam ID3 format" do
      expect(described_class.steam_id_to_community_id("[U:1:231702]")).to eq(76561197960497430)
    end

    it "converts STEAM_X format" do
      expect(described_class.steam_id_to_community_id("STEAM_0:0:5253998")).to eq(76561197970773724)
    end

    it "returns nil for Console" do
      expect(described_class.steam_id_to_community_id("Console")).to be_nil
    end

    it "returns nil for BOT" do
      expect(described_class.steam_id_to_community_id("BOT")).to be_nil
    end

    it "returns nil for blank" do
      expect(described_class.steam_id_to_community_id("")).to be_nil
    end
  end
end
