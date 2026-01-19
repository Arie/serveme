# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mcp::Tools::GetDiscordLinkTool do
  describe "class methods" do
    it "has the correct tool name" do
      expect(described_class.tool_name).to eq("get_discord_link")
    end

    it "has a description" do
      expect(described_class.description).to be_a(String)
      expect(described_class.description).not_to be_empty
    end

    it "requires public role" do
      expect(described_class.required_role).to eq(:public)
    end

    it "has an input schema with discord_uid" do
      schema = described_class.input_schema

      expect(schema[:type]).to eq("object")
      expect(schema[:properties]).to have_key(:discord_uid)
      expect(schema[:required]).to include("discord_uid")
    end
  end

  describe "#execute" do
    let(:user) { create(:user) }
    let(:tool) { described_class.new(user) }

    context "when discord_uid is linked" do
      let!(:linked_user) do
        create(:user,
          nickname: "LinkedPlayer",
          uid: "76561198012345678",
          discord_uid: "123456789012345678"
        )
      end

      it "returns the linked user info" do
        result = tool.execute(discord_uid: "123456789012345678")

        expect(result[:linked]).to be true
        expect(result[:steam_uid]).to eq("76561198012345678")
        expect(result[:nickname]).to eq("LinkedPlayer")
      end
    end

    context "when discord_uid is not linked" do
      it "returns linked: false" do
        result = tool.execute(discord_uid: "999999999999999999")

        expect(result[:linked]).to be false
        expect(result[:steam_uid]).to be_nil
      end
    end

    context "with missing discord_uid" do
      it "returns an error" do
        result = tool.execute({})

        expect(result[:error]).to include("discord_uid")
      end
    end
  end
end
