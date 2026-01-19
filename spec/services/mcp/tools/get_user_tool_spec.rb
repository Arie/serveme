# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mcp::Tools::GetUserTool do
  describe "class methods" do
    it "has the correct tool name" do
      expect(described_class.tool_name).to eq("get_user")
    end

    it "has a description" do
      expect(described_class.description).to be_a(String)
      expect(described_class.description).not_to be_empty
    end

    it "requires admin role" do
      expect(described_class.required_role).to eq(:admin)
    end

    it "has an input schema with query property" do
      schema = described_class.input_schema

      expect(schema[:type]).to eq("object")
      expect(schema[:properties]).to have_key(:query)
      expect(schema[:required]).to include("query")
    end
  end

  describe "#execute" do
    let(:admin_user) { create(:user, :admin) }
    let(:tool) { described_class.new(admin_user) }

    let!(:target_user) do
      create(:user,
        uid: "76561198012345678",
        nickname: "TestPlayer",
        name: "Test Player Name"
      )
    end

    context "with Steam ID64" do
      it "finds user by Steam ID64" do
        result = tool.execute(query: "76561198012345678")

        expect(result[:user]).to be_present
        expect(result[:user][:uid]).to eq("76561198012345678")
        expect(result[:user][:nickname]).to eq("TestPlayer")
      end
    end

    context "with nickname" do
      it "finds user by nickname (single result)" do
        result = tool.execute(query: "TestPlayer")

        # Single result returns :user, multiple returns :users
        expect(result[:user][:uid]).to eq("76561198012345678")
      end

      context "with multiple matches" do
        let!(:another_user) { create(:user, nickname: "TestPlayer2", uid: "76561198099999999") }

        it "returns multiple users for partial match" do
          result = tool.execute(query: "TestPlayer")

          expect(result[:users]).to be_an(Array)
          expect(result[:users].size).to be >= 1
        end
      end
    end

    context "with user ID" do
      it "finds user by ID with # prefix" do
        result = tool.execute(query: "##{target_user.id}")

        expect(result[:user]).to be_present
        expect(result[:user][:id]).to eq(target_user.id)
      end
    end

    context "with non-existent user" do
      it "returns not found message" do
        result = tool.execute(query: "76561199999999999")

        expect(result[:user]).to be_nil
        expect(result[:error]).to include("not found")
      end
    end

    context "with blank query" do
      it "returns error" do
        result = tool.execute(query: "")

        expect(result[:error]).to include("required")
      end
    end

    context "with user having reservations" do
      let!(:reservation) { create(:reservation, user: target_user) }

      it "includes reservation count" do
        result = tool.execute(query: "76561198012345678")

        expect(result[:user][:reservation_count]).to eq(1)
      end
    end

    context "with donator user" do
      before do
        target_user.groups << Group.donator_group
      end

      it "indicates donator status" do
        result = tool.execute(query: "76561198012345678")

        expect(result[:user][:donator]).to be true
      end
    end
  end
end
