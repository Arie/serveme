# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mcp::Tools::CreateWhitelistTool do
  describe "class methods" do
    it "has the correct tool name" do
      expect(described_class.tool_name).to eq("create_whitelist")
    end

    it "has a description" do
      expect(described_class.description).to be_a(String)
      expect(described_class.description).not_to be_empty
    end

    it "requires admin role" do
      expect(described_class.required_role).to eq(:admin)
    end

    it "has an input schema with required file" do
      schema = described_class.input_schema

      expect(schema[:type]).to eq("object")
      expect(schema[:properties]).to have_key(:file)
      expect(schema[:properties]).to have_key(:hidden)
      expect(schema[:required]).to include("file")
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

    it "creates a new whitelist" do
      result = tool.execute(file: "new_whitelist")

      expect(result[:success]).to be true
      expect(result[:whitelist][:file]).to eq("new_whitelist")
      expect(result[:whitelist][:hidden]).to be false

      expect(Whitelist.find_by(file: "new_whitelist")).to be_present
    end

    it "creates a hidden whitelist when specified" do
      result = tool.execute(file: "hidden_whitelist", hidden: true)

      expect(result[:success]).to be true
      expect(result[:whitelist][:hidden]).to be true

      whitelist = Whitelist.find_by(file: "hidden_whitelist")
      expect(whitelist.hidden).to be true
    end

    it "fails if whitelist already exists" do
      create(:whitelist, file: "existing_whitelist")

      result = tool.execute(file: "existing_whitelist")

      expect(result[:success]).to be false
      expect(result[:error]).to include("already exists")
    end

    it "fails if whitelist already exists (case-insensitive)" do
      create(:whitelist, file: "Existing_Whitelist")

      result = tool.execute(file: "existing_whitelist")

      expect(result[:success]).to be false
      expect(result[:error]).to include("already exists")
    end

    it "strips whitespace from file name" do
      result = tool.execute(file: "  spaced_whitelist  ")

      expect(result[:success]).to be true
      expect(result[:whitelist][:file]).to eq("spaced_whitelist")
    end
  end
end
