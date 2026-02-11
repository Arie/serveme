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
    context "when API user links their own account" do
      let(:user) { create(:user, nickname: "TestPlayer", uid: "76561198012345678") }
      let(:tool) { described_class.new(user) }

      it "links discord account successfully" do
        result = tool.execute(discord_uid: "123456789012345678", steam_uid: user.uid)

        expect(result[:success]).to be true
        expect(result[:user][:nickname]).to eq("TestPlayer")
        expect(user.reload.discord_uid).to eq("123456789012345678")
      end

      it "returns linked user info" do
        result = tool.execute(discord_uid: "123456789012345678", steam_uid: user.uid)

        expect(result[:user]).to include(:nickname, :steam_uid, :discord_uid)
        expect(result[:user][:discord_uid]).to eq("123456789012345678")
      end
    end

    context "when non-privileged user tries to link another user" do
      let(:user) { create(:user) }
      let(:target_user) { create(:user, nickname: "TargetPlayer", uid: "76561198012345678") }
      let(:tool) { described_class.new(user) }

      it "returns authorization error" do
        result = tool.execute(discord_uid: "123456789012345678", steam_uid: target_user.uid)

        expect(result[:success]).to be false
        expect(result[:error]).to include("Not authorized")
      end
    end

    context "when privileged user (admin) links another user" do
      let(:admin) { create(:user, :admin) }
      let(:target_user) { create(:user, nickname: "TargetPlayer", uid: "76561198012345678") }
      let(:tool) { described_class.new(admin) }

      it "links discord account successfully" do
        result = tool.execute(discord_uid: "123456789012345678", steam_uid: target_user.uid)

        expect(result[:success]).to be true
        expect(target_user.reload.discord_uid).to eq("123456789012345678")
      end
    end

    context "when user not found" do
      let(:user) { create(:user) }
      let(:tool) { described_class.new(user) }

      it "returns error" do
        result = tool.execute(discord_uid: "123456789012345678", steam_uid: "76561198099999999")

        expect(result[:success]).to be false
        expect(result[:error]).to include("not found")
      end
    end

    context "when discord already linked to another user" do
      let(:admin) { create(:user, :admin) }
      let(:target_user) { create(:user, uid: "76561198012345678") }
      let!(:other_user) { create(:user, uid: "76561198011111111", discord_uid: "123456789012345678") }
      let(:tool) { described_class.new(admin) }

      it "returns error" do
        result = tool.execute(discord_uid: "123456789012345678", steam_uid: target_user.uid)

        expect(result[:success]).to be false
        expect(result[:error]).to include("already linked")
      end
    end

    context "when user already has a different discord linked" do
      let(:user) { create(:user, uid: "76561198012345678", discord_uid: "999999999999999999") }
      let(:tool) { described_class.new(user) }

      it "updates the link" do
        result = tool.execute(discord_uid: "123456789012345678", steam_uid: user.uid)

        expect(result[:success]).to be true
        expect(user.reload.discord_uid).to eq("123456789012345678")
      end
    end

    context "with missing parameters" do
      let(:user) { create(:user, uid: "76561198012345678") }
      let(:tool) { described_class.new(user) }

      it "returns error when discord_uid missing" do
        result = tool.execute(steam_uid: user.uid)

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
    context "when unlinking own account" do
      let(:user) { create(:user, uid: "76561198012345678", discord_uid: "123456789012345678") }
      let(:tool) { described_class.new(user) }

      it "can unlink discord" do
        result = tool.execute(discord_uid: "123456789012345678", steam_uid: user.uid, unlink: true)

        expect(result[:success]).to be true
        expect(user.reload.discord_uid).to be_nil
      end
    end

    context "when non-privileged user tries to unlink another user" do
      let(:user) { create(:user) }
      let(:linked_user) { create(:user, uid: "76561198012345678", discord_uid: "123456789012345678") }
      let(:tool) { described_class.new(user) }

      it "returns authorization error" do
        result = tool.execute(discord_uid: "123456789012345678", steam_uid: linked_user.uid, unlink: true)

        expect(result[:success]).to be false
        expect(result[:error]).to include("Not authorized")
      end
    end
  end
end
