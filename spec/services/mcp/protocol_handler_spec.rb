# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mcp::ProtocolHandler do
  let(:admin_user) { create(:user, :admin) }
  let(:handler) { described_class.new(admin_user) }

  describe "#handle" do
    context "with tools/list request" do
      let(:request) do
        {
          jsonrpc: "2.0",
          id: 1,
          method: "tools/list"
        }.to_json
      end

      it "returns list of available tools" do
        result = handler.handle(request)

        expect(result[:jsonrpc]).to eq("2.0")
        expect(result[:id]).to eq(1)
        expect(result[:result][:tools]).to be_an(Array)
      end
    end

    context "with tools/call request" do
      let(:request) do
        {
          jsonrpc: "2.0",
          id: 2,
          method: "tools/call",
          params: {
            name: "search_alts",
            arguments: {
              steam_uid: "76561198012345678"
            }
          }
        }.to_json
      end

      it "executes the tool and returns result" do
        result = handler.handle(request)

        expect(result[:jsonrpc]).to eq("2.0")
        expect(result[:id]).to eq(2)
        expect(result[:result]).to have_key(:content)
      end
    end

    context "with unknown tool" do
      let(:request) do
        {
          jsonrpc: "2.0",
          id: 3,
          method: "tools/call",
          params: {
            name: "nonexistent_tool",
            arguments: {}
          }
        }.to_json
      end

      it "returns an error" do
        result = handler.handle(request)

        expect(result[:jsonrpc]).to eq("2.0")
        expect(result[:id]).to eq(3)
        expect(result[:error]).to be_present
        expect(result[:error][:code]).to eq(-32601)
      end
    end

    context "with unauthorized tool" do
      let(:regular_user) { create(:user) }
      let(:handler) { described_class.new(regular_user) }
      let(:request) do
        {
          jsonrpc: "2.0",
          id: 4,
          method: "tools/call",
          params: {
            name: "search_alts",
            arguments: {}
          }
        }.to_json
      end

      it "returns a permission error" do
        result = handler.handle(request)

        expect(result[:error]).to be_present
        expect(result[:error][:code]).to eq(-32600)
        expect(result[:error][:message]).to include("permission")
      end
    end

    context "with invalid JSON" do
      it "returns a parse error" do
        result = handler.handle("not valid json")

        expect(result[:error][:code]).to eq(-32700)
      end
    end

    context "with unknown method" do
      let(:request) do
        {
          jsonrpc: "2.0",
          id: 5,
          method: "unknown/method"
        }.to_json
      end

      it "returns method not found error" do
        result = handler.handle(request)

        expect(result[:error][:code]).to eq(-32601)
      end
    end
  end
end
