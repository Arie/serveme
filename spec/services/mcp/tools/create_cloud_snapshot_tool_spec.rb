# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mcp::Tools::CreateCloudSnapshotTool do
  describe "class methods" do
    it "has the correct tool name" do
      expect(described_class.tool_name).to eq("create_cloud_snapshot")
    end

    it "has a description" do
      expect(described_class.description).to be_a(String)
      expect(described_class.description).not_to be_empty
    end

    it "requires admin role" do
      expect(described_class.required_role).to eq(:admin)
    end

    it "has an input schema" do
      schema = described_class.input_schema
      expect(schema[:type]).to eq("object")
      expect(schema[:properties]).to have_key(:location)
    end
  end

  describe "#execute" do
    let(:admin_user) { create(:user, :admin) }
    let(:tool) { described_class.new(admin_user) }

    it "queues a CloudSnapshotWorker with default location" do
      expect(CloudSnapshotWorker).to receive(:perform_async).with("hetzner", "fsn1")

      result = tool.execute({})

      expect(result[:status]).to eq("queued")
      expect(result[:provider]).to eq("hetzner")
      expect(result[:location]).to eq("fsn1")
    end

    it "queues with a custom location" do
      expect(CloudSnapshotWorker).to receive(:perform_async).with("hetzner", "nbg1")

      result = tool.execute(location: "nbg1")

      expect(result[:status]).to eq("queued")
      expect(result[:location]).to eq("nbg1")
    end

    it "returns an error for unknown locations" do
      result = tool.execute(location: "invalid")

      expect(result[:error]).to include("Unknown Hetzner location")
    end
  end
end
