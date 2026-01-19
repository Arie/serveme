# typed: false
# frozen_string_literal: true

require "spec_helper"

# Test tool classes defined outside of RSpec blocks to satisfy Sorbet/BlockMethodDefinition
module Mcp
  module Tools
    class TestAdminTool < BaseTool
      def self.tool_name = "admin_tool"
      def self.description = "Admin only tool"
      def self.input_schema = { type: "object", properties: {} }
      def self.required_role = :admin
    end

    class TestLeagueTool < BaseTool
      def self.tool_name = "league_tool"
      def self.description = "League admin tool"
      def self.input_schema = { type: "object", properties: {} }
      def self.required_role = :league_admin
    end

    class TestPublicTool < BaseTool
      def self.tool_name = "public_tool"
      def self.description = "Public tool"
      def self.input_schema = { type: "object", properties: {} }
      def self.required_role = :public
    end

    class TestDefinitionTool < BaseTool
      def self.tool_name = "test_tool"
      def self.description = "A test tool"

      def self.input_schema
        {
          type: "object",
          properties: {
            query: { type: "string", description: "Search query" }
          },
          required: [ "query" ]
        }
      end
    end
  end
end

RSpec.describe Mcp::Tools::BaseTool do
  let(:admin_user) { create(:user, :admin) }

  describe "class interface" do
    it "requires subclasses to implement .name" do
      expect { described_class.tool_name }.to raise_error(NotImplementedError)
    end

    it "requires subclasses to implement .description" do
      expect { described_class.description }.to raise_error(NotImplementedError)
    end

    it "requires subclasses to implement .input_schema" do
      expect { described_class.input_schema }.to raise_error(NotImplementedError)
    end

    it "has a default required_role of :admin" do
      expect(described_class.required_role).to eq(:admin)
    end
  end

  describe ".available_to?" do
    let(:league_admin_user) do
      user = create(:user)
      user.groups << Group.league_admin_group
      user
    end
    let(:regular_user) { create(:user) }

    context "with a tool requiring :admin role" do
      it "returns true for admin users" do
        expect(Mcp::Tools::TestAdminTool.available_to?(admin_user)).to be true
      end

      it "returns false for league admin users" do
        expect(Mcp::Tools::TestAdminTool.available_to?(league_admin_user)).to be false
      end

      it "returns false for regular users" do
        expect(Mcp::Tools::TestAdminTool.available_to?(regular_user)).to be false
      end
    end

    context "with a tool requiring :league_admin role" do
      it "returns true for admin users" do
        expect(Mcp::Tools::TestLeagueTool.available_to?(admin_user)).to be true
      end

      it "returns true for league admin users" do
        expect(Mcp::Tools::TestLeagueTool.available_to?(league_admin_user)).to be true
      end

      it "returns false for regular users" do
        expect(Mcp::Tools::TestLeagueTool.available_to?(regular_user)).to be false
      end
    end

    context "with a tool requiring :public role" do
      it "returns true for admin users" do
        expect(Mcp::Tools::TestPublicTool.available_to?(admin_user)).to be true
      end

      it "returns true for league admin users" do
        expect(Mcp::Tools::TestPublicTool.available_to?(league_admin_user)).to be true
      end

      it "returns true for regular users" do
        expect(Mcp::Tools::TestPublicTool.available_to?(regular_user)).to be true
      end
    end
  end

  describe "#execute" do
    it "requires subclasses to implement #execute" do
      tool = described_class.new(admin_user)
      expect { tool.execute({}) }.to raise_error(NotImplementedError)
    end
  end

  describe ".to_mcp_definition" do
    it "returns MCP-formatted tool definition" do
      definition = Mcp::Tools::TestDefinitionTool.to_mcp_definition

      expect(definition).to eq(
        name: "test_tool",
        description: "A test tool",
        inputSchema: {
          type: "object",
          properties: {
            query: { type: "string", description: "Search query" }
          },
          required: [ "query" ]
        }
      )
    end
  end
end
