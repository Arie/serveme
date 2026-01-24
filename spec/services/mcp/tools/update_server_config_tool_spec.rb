# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mcp::Tools::UpdateServerConfigTool do
  describe "class methods" do
    it "has the correct tool name" do
      expect(described_class.tool_name).to eq("update_server_config")
    end

    it "has a description" do
      expect(described_class.description).to be_a(String)
      expect(described_class.description).not_to be_empty
    end

    it "requires admin role" do
      expect(described_class.required_role).to eq(:admin)
    end

    it "has an input schema with required hidden" do
      schema = described_class.input_schema

      expect(schema[:type]).to eq("object")
      expect(schema[:properties]).to have_key(:id)
      expect(schema[:properties]).to have_key(:file)
      expect(schema[:properties]).to have_key(:hidden)
      expect(schema[:required]).to include("hidden")
    end
  end

  describe ".available_to?" do
    it "is not available to regular users" do
      user = create(:user)
      expect(described_class.available_to?(user)).to be false
    end

    it "is available to admins" do
      user = create(:user, :admin)
      expect(described_class.available_to?(user)).to be true
    end
  end

  describe "#execute" do
    let(:admin) { create(:user, :admin) }
    let(:tool) { described_class.new(admin) }
    let!(:config) { create(:server_config, file: "test_config", hidden: false) }

    it "updates hidden status by id" do
      result = tool.execute(id: config.id, hidden: true)

      expect(result[:success]).to be true
      expect(result[:config][:hidden]).to be true

      config.reload
      expect(config.hidden).to be true
    end

    it "updates hidden status by file name" do
      result = tool.execute(file: "test_config", hidden: true)

      expect(result[:success]).to be true
      expect(result[:config][:hidden]).to be true

      config.reload
      expect(config.hidden).to be true
    end

    it "finds config case-insensitively" do
      result = tool.execute(file: "TEST_CONFIG", hidden: true)

      expect(result[:success]).to be true
      config.reload
      expect(config.hidden).to be true
    end

    it "can unhide a hidden config" do
      config.update!(hidden: true)

      result = tool.execute(id: config.id, hidden: false)

      expect(result[:success]).to be true
      expect(result[:config][:hidden]).to be false

      config.reload
      expect(config.hidden).to be false
    end

    it "fails if config not found by id" do
      result = tool.execute(id: 999999, hidden: true)

      expect(result[:success]).to be false
      expect(result[:error]).to eq("Config not found")
    end

    it "fails if config not found by file" do
      result = tool.execute(file: "nonexistent", hidden: true)

      expect(result[:success]).to be false
      expect(result[:error]).to eq("Config not found")
    end

    it "fails if neither id nor file provided" do
      result = tool.execute(hidden: true)

      expect(result[:success]).to be false
      expect(result[:error]).to eq("Config not found")
    end

    it "fails if hidden parameter not provided" do
      result = tool.execute(id: config.id)

      expect(result[:success]).to be false
      expect(result[:error]).to include("hidden parameter is required")
    end
  end
end
