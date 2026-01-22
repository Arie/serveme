# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mcp::Tools::SearchByAsnTool do
  describe "class methods" do
    it "has the correct tool name" do
      expect(described_class.tool_name).to eq("search_by_asn")
    end

    it "has a description" do
      expect(described_class.description).to be_a(String)
      expect(described_class.description).not_to be_empty
    end

    it "requires league_admin role" do
      expect(described_class.required_role).to eq(:league_admin)
    end

    it "has an input schema with asn_number property" do
      schema = described_class.input_schema

      expect(schema[:type]).to eq("object")
      expect(schema[:properties]).to have_key(:asn_number)
      expect(schema[:properties]).to have_key(:days)
      expect(schema[:properties]).to have_key(:limit)
      expect(schema[:required]).to include("asn_number")
    end
  end

  describe "#execute" do
    let(:admin_user) { create(:user, :admin) }
    let(:tool) { described_class.new(admin_user) }

    let(:asn_number) { 8708 }
    let(:asn_organization) { "Digi Romania S.A." }
    let!(:reservation) { create(:reservation) }
    let!(:reservation_player) do
      player = create(:reservation_player,
        reservation: reservation,
        steam_uid: "76561198012345678",
        ip: "82.78.173.17",
        name: "TestPlayer"
      )
      # Use update_columns to bypass the before_save callback that looks up ASN
      player.update_columns(asn_number: asn_number, asn_organization: asn_organization)
      player
    end

    context "with valid asn_number parameter" do
      it "returns accounts for the ASN" do
        result = tool.execute(asn_number: asn_number)

        expect(result[:accounts]).to be_an(Array)
        expect(result[:asn_number]).to eq(asn_number)
        expect(result[:error]).to be_nil
      end

      it "includes account details" do
        result = tool.execute(asn_number: asn_number)

        expect(result[:accounts].first).to include(
          steam_uid: "76561198012345678",
          name: "TestPlayer"
        )
      end
    end

    context "with days parameter" do
      let!(:old_reservation) do
        r = create(:reservation)
        r.update_columns(starts_at: 100.days.ago, ends_at: 100.days.ago + 2.hours)
        r
      end
      let!(:old_player) do
        player = create(:reservation_player,
          reservation: old_reservation,
          steam_uid: "76561198099999999",
          ip: "82.78.0.1",
          name: "OldPlayer"
        )
        player.update_columns(asn_number: asn_number, asn_organization: asn_organization)
        player
      end

      it "filters by date range" do
        result = tool.execute(asn_number: asn_number, days: 30)

        steam_uids = result[:accounts].map { |a| a[:steam_uid] }
        expect(steam_uids).to include("76561198012345678")
        expect(steam_uids).not_to include("76561198099999999")
      end
    end

    context "with invalid asn_number" do
      it "returns error for zero" do
        result = tool.execute(asn_number: 0)

        expect(result[:error]).to include("Valid ASN number is required")
        expect(result[:accounts]).to eq([])
      end

      it "returns error for nil" do
        result = tool.execute({})

        expect(result[:error]).to include("Valid ASN number is required")
        expect(result[:accounts]).to eq([])
      end
    end

    context "with limit parameter" do
      before do
        5.times do |i|
          r = create(:reservation)
          player = create(:reservation_player,
            reservation: r,
            steam_uid: "7656119800000000#{i}",
            ip: "82.78.0.#{i}",
            name: "Player#{i}"
          )
          player.update_columns(asn_number: asn_number, asn_organization: asn_organization)
        end
      end

      it "respects the limit" do
        result = tool.execute(asn_number: asn_number, limit: 3)

        expect(result[:accounts].size).to eq(3)
      end
    end
  end
end
