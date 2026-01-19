# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mcp::ToolRegistry do
  describe ".tools" do
    it "returns an array of tool classes" do
      expect(described_class.tools).to be_an(Array)
      expect(described_class.tools).to all(be < Mcp::Tools::BaseTool)
    end
  end

  describe ".find" do
    it "finds a tool by name" do
      tool = described_class.find("search_alts")
      expect(tool).to eq(Mcp::Tools::SearchAltsTool)
    end

    it "returns nil for unknown tool" do
      expect(described_class.find("nonexistent")).to be_nil
    end
  end

  describe ".available_tools" do
    let(:admin_user) { create(:user, :admin) }
    let(:league_admin_user) do
      user = create(:user)
      user.groups << Group.league_admin_group
      user
    end
    let(:regular_user) { create(:user) }

    it "returns tools available to admin users" do
      tools = described_class.available_tools(admin_user)
      expect(tools).to be_an(Array)
      expect(tools.map { |t| t[:name] }).to include("search_alts")
    end

    it "returns tools available to league admin users" do
      tools = described_class.available_tools(league_admin_user)
      expect(tools.map { |t| t[:name] }).to include("search_alts")
    end

    it "returns public tools for regular users" do
      tools = described_class.available_tools(regular_user)
      tool_names = tools.map { |t| t[:name] }

      # Regular users should have access to public tools
      expect(tool_names).to include("get_public_servers", "get_player_reservations", "link_discord")
      # But not admin tools
      expect(tool_names).not_to include("search_alts", "get_user", "list_servers", "list_reservations")
    end

    it "returns tool definitions in MCP format" do
      tools = described_class.available_tools(admin_user)
      tool = tools.find { |t| t[:name] == "search_alts" }

      expect(tool).to include(
        name: "search_alts",
        description: a_kind_of(String),
        inputSchema: a_kind_of(Hash)
      )
    end
  end
end
