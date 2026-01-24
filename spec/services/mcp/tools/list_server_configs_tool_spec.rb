# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mcp::Tools::ListServerConfigsTool do
  describe "class methods" do
    it "has the correct tool name" do
      expect(described_class.tool_name).to eq("list_server_configs")
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
    let!(:visible_config) { create(:server_config, file: "etf2l_6v6", hidden: false) }
    let!(:hidden_config) { create(:server_config, file: "hidden_test", hidden: true) }

    context "for regular users" do
      let(:user) { create(:user) }
      let(:tool) { described_class.new(user) }

      it "returns only visible configs" do
        result = tool.execute({})

        config_names = result[:configs].map { |c| c[:file] }
        expect(config_names).to include("etf2l_6v6")
        expect(config_names).not_to include("hidden_test")
      end

      it "does not include hidden status in response" do
        result = tool.execute({})

        config = result[:configs].find { |c| c[:file] == "etf2l_6v6" }
        expect(config).not_to have_key(:hidden)
      end

      it "ignores include_hidden parameter" do
        result = tool.execute(include_hidden: true)

        config_names = result[:configs].map { |c| c[:file] }
        expect(config_names).not_to include("hidden_test")
      end
    end

    context "for admin users" do
      let(:user) { create(:user, :admin) }
      let(:tool) { described_class.new(user) }

      it "returns all configs by default including hidden" do
        result = tool.execute({})

        config_names = result[:configs].map { |c| c[:file] }
        expect(config_names).to include("etf2l_6v6")
        expect(config_names).to include("hidden_test")
      end

      it "includes hidden status in response" do
        result = tool.execute({})

        config = result[:configs].find { |c| c[:file] == "hidden_test" }
        expect(config).to have_key(:hidden)
        expect(config[:hidden]).to be true
      end

      it "can filter to visible only with include_hidden: false" do
        result = tool.execute(include_hidden: false)

        config_names = result[:configs].map { |c| c[:file] }
        expect(config_names).to include("etf2l_6v6")
        expect(config_names).not_to include("hidden_test")
      end
    end

    context "with query filter" do
      let(:user) { create(:user) }
      let(:tool) { described_class.new(user) }

      it "filters by config name" do
        result = tool.execute(query: "etf2l")

        config_names = result[:configs].map { |c| c[:file] }
        expect(config_names).to include("etf2l_6v6")
      end

      it "is case-insensitive" do
        result = tool.execute(query: "ETF2L")

        config_names = result[:configs].map { |c| c[:file] }
        expect(config_names).to include("etf2l_6v6")
      end
    end

    it "returns config count" do
      user = create(:user)
      tool = described_class.new(user)
      result = tool.execute({})

      expect(result[:config_count]).to be_a(Integer)
      expect(result[:config_count]).to be >= 1
    end
  end
end
