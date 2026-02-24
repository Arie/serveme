# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mcp::Tools::BuildCloudImageTool do
  describe "class methods" do
    it "has the correct tool name" do
      expect(described_class.tool_name).to eq("build_cloud_image")
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
    end
  end

  describe "#execute" do
    let(:admin_user) { create(:user, :admin) }
    let(:tool) { described_class.new(admin_user) }

    context "on EU region" do
      before do
        stub_const("SITE_HOST", "serveme.tf")
      end

      it "queues a CloudImageBuildWorker" do
        expect(CloudImageBuildWorker).to receive(:perform_async).with(100_000_000)

        result = tool.execute({})

        expect(result[:status]).to eq("queued")
        expect(result[:version]).to eq(100_000_000)
      end
    end

    context "on non-EU region" do
      before do
        stub_const("SITE_HOST", "na.serveme.tf")
      end

      it "returns an error" do
        result = tool.execute({})

        expect(result[:error]).to include("EU region")
      end
    end
  end
end
