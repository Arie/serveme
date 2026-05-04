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

      it "creates a CloudImageBuild record and enqueues the worker by id" do
        allow(Server).to receive(:latest_version).and_return("100000000")
        expect(CloudImageBuildWorker).to receive(:perform_async).with(kind_of(Integer))

        expect { tool.execute({}) }.to change(CloudImageBuild, :count).by(1)

        build = CloudImageBuild.last
        expect(build.version).to eq("100000000")
        expect(build.force_pull).to eq(false)
        expect(build.status).to eq("queued")
      end

      it "returns the build_id in the response" do
        allow(Server).to receive(:latest_version).and_return("100000000")
        allow(CloudImageBuildWorker).to receive(:perform_async)

        result = tool.execute({})

        expect(result[:status]).to eq("queued")
        expect(result[:version]).to eq("100000000")
        expect(result[:build_id]).to eq(CloudImageBuild.last.id)
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
