# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mcp::Tools::BuildWebsocketEchoImageTool do
  describe "class methods" do
    it "exposes the expected MCP metadata" do
      expect(described_class.tool_name).to eq("build_websocket_echo_image")
      expect(described_class.description).to be_a(String).and(be_present)
      expect(described_class.required_role).to eq(:admin)
      expect(described_class.input_schema[:type]).to eq("object")
    end
  end

  describe "#execute" do
    let(:tool) { described_class.new(create(:user, :admin)) }

    it "queues the build worker on the EU region" do
      stub_const("SITE_HOST", "serveme.tf")
      expect(BuildWebsocketEchoImageWorker).to receive(:perform_async)
      result = tool.execute({})
      expect(result[:status]).to eq("queued")
    end

    it "refuses to run on a non-EU region" do
      stub_const("SITE_HOST", "na.serveme.tf")
      expect(BuildWebsocketEchoImageWorker).not_to receive(:perform_async)
      result = tool.execute({})
      expect(result[:error]).to include("EU region")
    end
  end
end
