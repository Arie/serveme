# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mcp::Tools::ListWhitelistsTool do
  describe "class methods" do
    it "has the correct tool name" do
      expect(described_class.tool_name).to eq("list_whitelists")
    end

    it "has a description" do
      expect(described_class.description).to be_a(String)
      expect(described_class.description).not_to be_empty
    end

    it "requires public role (available to all)" do
      expect(described_class.required_role).to eq(:public)
    end

    it "has an input schema" do
      schema = described_class.input_schema

      expect(schema[:type]).to eq("object")
      expect(schema[:properties]).to have_key(:query)
      expect(schema[:properties]).to have_key(:include_hidden)
    end
  end

  describe ".available_to?" do
    it "is available to regular users" do
      user = create(:user)
      expect(described_class.available_to?(user)).to be true
    end

    it "is available to admins" do
      user = create(:user, :admin)
      expect(described_class.available_to?(user)).to be true
    end
  end

  describe "#execute" do
    let!(:visible_whitelist) { create(:whitelist, file: "etf2l_whitelist_6v6", hidden: false) }
    let!(:hidden_whitelist) { create(:whitelist, file: "hidden_whitelist", hidden: true) }

    context "for regular users" do
      let(:user) { create(:user) }
      let(:tool) { described_class.new(user) }

      it "returns only visible whitelists" do
        result = tool.execute({})

        whitelist_names = result[:whitelists].map { |w| w[:file] }
        expect(whitelist_names).to include("etf2l_whitelist_6v6")
        expect(whitelist_names).not_to include("hidden_whitelist")
      end

      it "does not include hidden status in response" do
        result = tool.execute({})

        whitelist = result[:whitelists].find { |w| w[:file] == "etf2l_whitelist_6v6" }
        expect(whitelist).not_to have_key(:hidden)
      end

      it "ignores include_hidden parameter" do
        result = tool.execute(include_hidden: true)

        whitelist_names = result[:whitelists].map { |w| w[:file] }
        expect(whitelist_names).not_to include("hidden_whitelist")
      end
    end

    context "for admin users" do
      let(:user) { create(:user, :admin) }
      let(:tool) { described_class.new(user) }

      it "returns all whitelists by default including hidden" do
        result = tool.execute({})

        whitelist_names = result[:whitelists].map { |w| w[:file] }
        expect(whitelist_names).to include("etf2l_whitelist_6v6")
        expect(whitelist_names).to include("hidden_whitelist")
      end

      it "includes hidden status in response" do
        result = tool.execute({})

        whitelist = result[:whitelists].find { |w| w[:file] == "hidden_whitelist" }
        expect(whitelist).to have_key(:hidden)
        expect(whitelist[:hidden]).to be true
      end

      it "can filter to visible only with include_hidden: false" do
        result = tool.execute(include_hidden: false)

        whitelist_names = result[:whitelists].map { |w| w[:file] }
        expect(whitelist_names).to include("etf2l_whitelist_6v6")
        expect(whitelist_names).not_to include("hidden_whitelist")
      end
    end

    context "with query filter" do
      let(:user) { create(:user) }
      let(:tool) { described_class.new(user) }

      it "filters by whitelist name" do
        result = tool.execute(query: "etf2l")

        whitelist_names = result[:whitelists].map { |w| w[:file] }
        expect(whitelist_names).to include("etf2l_whitelist_6v6")
      end

      it "is case-insensitive" do
        result = tool.execute(query: "ETF2L")

        whitelist_names = result[:whitelists].map { |w| w[:file] }
        expect(whitelist_names).to include("etf2l_whitelist_6v6")
      end
    end

    it "returns whitelist count" do
      user = create(:user)
      tool = described_class.new(user)
      result = tool.execute({})

      expect(result[:whitelist_count]).to be_a(Integer)
      expect(result[:whitelist_count]).to be >= 1
    end
  end
end
