# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mcp::Tools::SearchAltsTool do
  describe "class methods" do
    it "has the correct tool name" do
      expect(described_class.tool_name).to eq("search_alts")
    end

    it "has a description" do
      expect(described_class.description).to be_a(String)
      expect(described_class.description).not_to be_empty
    end

    it "requires league_admin role" do
      expect(described_class.required_role).to eq(:league_admin)
    end

    it "has an input schema with steam_uid and ip properties" do
      schema = described_class.input_schema

      expect(schema[:type]).to eq("object")
      expect(schema[:properties]).to have_key(:steam_uid)
      expect(schema[:properties]).to have_key(:ip)
      expect(schema[:properties]).to have_key(:cross_reference)
    end
  end

  describe "#execute" do
    let(:admin_user) { create(:user, :admin) }
    let(:tool) { described_class.new(admin_user) }

    let(:suspect_uid) { "76561198012345678" }
    let(:suspect_ip) { "192.168.1.100" }
    let!(:reservation) { create(:reservation) }
    let!(:reservation_player) do
      create(:reservation_player,
        reservation: reservation,
        steam_uid: suspect_uid,
        ip: suspect_ip,
        name: "SuspectPlayer"
      )
    end

    context "with steam_uid parameter" do
      it "returns search results for the steam_uid" do
        result = tool.execute(steam_uid: suspect_uid)

        expect(result[:results]).to be_an(Array)
        expect(result[:target]).to include(suspect_uid)
      end
    end

    context "with ip parameter" do
      it "returns search results for the ip" do
        result = tool.execute(ip: suspect_ip)

        expect(result[:results]).to be_an(Array)
        expect(result[:target]).to include(suspect_ip)
      end
    end

    context "with cross_reference enabled" do
      let(:other_ip) { "192.168.1.200" }
      let!(:other_player) do
        create(:reservation_player,
          reservation: reservation,
          steam_uid: suspect_uid,
          ip: other_ip,
          name: "SamePlayerOtherIP"
        )
      end

      it "returns cross-referenced results" do
        result = tool.execute(steam_uid: suspect_uid, cross_reference: true)

        expect(result[:results]).to be_an(Array)
      end
    end

    context "with no parameters" do
      it "returns empty results" do
        result = tool.execute({})

        expect(result[:results]).to eq([])
        expect(result[:error]).to include("parameter")
      end
    end
  end
end
