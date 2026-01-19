# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mcp::Tools::LinkDiscordTool do
  describe "class methods" do
    it "has the correct tool name" do
      expect(described_class.tool_name).to eq("link_discord")
    end

    it "has a description" do
      expect(described_class.description).to be_a(String)
      expect(described_class.description).not_to be_empty
    end

    it "requires public role (available to all)" do
      expect(described_class.required_role).to eq(:public)
    end

    it "has an input schema with required parameters" do
      schema = described_class.input_schema

      expect(schema[:type]).to eq("object")
      expect(schema[:properties]).to have_key(:discord_uid)
      expect(schema[:properties]).to have_key(:steam_uid)
      expect(schema[:required]).to include("discord_uid", "steam_uid")
    end
  end

  describe "#execute" do
    let(:user) { create(:user) }
    let(:tool) { described_class.new(user) }

    let(:target_user) { create(:user, nickname: "TargetPlayer", uid: "76561198012345678") }

    context "with valid parameters" do
      it "links discord account to user" do
        result = tool.execute(discord_uid: "123456789012345678", steam_uid: target_user.uid)

        expect(result[:success]).to be true
        expect(result[:user][:nickname]).to eq("TargetPlayer")
        expect(target_user.reload.discord_uid).to eq("123456789012345678")
      end

      it "returns linked user info" do
        result = tool.execute(discord_uid: "123456789012345678", steam_uid: target_user.uid)

        expect(result[:user]).to include(:nickname, :steam_uid, :discord_uid)
        expect(result[:user][:discord_uid]).to eq("123456789012345678")
      end
    end

    context "when user not found" do
      it "returns error" do
        result = tool.execute(discord_uid: "123456789012345678", steam_uid: "76561198099999999")

        expect(result[:success]).to be false
        expect(result[:error]).to include("not found")
      end
    end

    context "when discord already linked to another user" do
      let!(:other_user) { create(:user, uid: "76561198011111111", discord_uid: "123456789012345678") }

      it "returns error" do
        result = tool.execute(discord_uid: "123456789012345678", steam_uid: target_user.uid)

        expect(result[:success]).to be false
        expect(result[:error]).to include("already linked")
      end
    end

    context "when user already has a different discord linked" do
      before { target_user.update!(discord_uid: "999999999999999999") }

      it "updates the link" do
        result = tool.execute(discord_uid: "123456789012345678", steam_uid: target_user.uid)

        expect(result[:success]).to be true
        expect(target_user.reload.discord_uid).to eq("123456789012345678")
      end
    end

    context "with missing parameters" do
      it "returns error when discord_uid missing" do
        result = tool.execute(steam_uid: target_user.uid)

        expect(result[:success]).to be false
        expect(result[:error]).to include("discord_uid")
      end

      it "returns error when steam_uid missing" do
        result = tool.execute(discord_uid: "123456789012345678")

        expect(result[:success]).to be false
        expect(result[:error]).to include("steam_uid")
      end
    end
  end

  describe "unlink functionality" do
    let(:user) { create(:user) }
    let(:tool) { described_class.new(user) }
    let(:linked_user) { create(:user, uid: "76561198012345678", discord_uid: "123456789012345678") }

    it "can unlink by setting discord_uid to null" do
      result = tool.execute(discord_uid: "123456789012345678", steam_uid: linked_user.uid, unlink: true)

      expect(result[:success]).to be true
      expect(linked_user.reload.discord_uid).to be_nil
    end
  end
end
