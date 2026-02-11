# typed: false
# frozen_string_literal: true

require "spec_helper"

describe Api::McpController do
  render_views

  describe "#tools" do
    context "without authentication" do
      it "returns unauthorized" do
        get :tools, format: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with regular user" do
      let(:user) { create(:user) }

      before do
        allow(controller).to receive(:api_user).and_return(user)
      end

      it "returns public tools only" do
        get :tools, format: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["tools"]).to be_an(Array)
        tool_names = json["tools"].map { |t| t["name"] }
        expect(tool_names).to include("get_public_servers", "create_reservation")
        expect(tool_names).not_to include("search_alts", "get_user", "list_servers")
      end
    end

    context "with admin user" do
      let(:admin) { create(:user, :admin) }

      before do
        allow(controller).to receive(:api_user).and_return(admin)
      end

      it "returns list of available tools" do
        get :tools, format: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["tools"]).to be_an(Array)
        expect(json["tools"].map { |t| t["name"] }).to include("search_alts", "get_user", "list_servers")
      end
    end

    context "with league admin user" do
      let(:league_admin) do
        user = create(:user)
        user.groups << Group.league_admin_group
        user
      end

      before do
        allow(controller).to receive(:api_user).and_return(league_admin)
      end

      it "returns tools available to league admin" do
        get :tools, format: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["tools"].map { |t| t["name"] }).to include("search_alts")
        # league admin should not see admin-only tools
        expect(json["tools"].map { |t| t["name"] }).not_to include("get_user")
      end
    end
  end

  describe "#execute" do
    context "without authentication" do
      it "returns unauthorized" do
        post :execute, format: :json, body: {}.to_json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with regular user" do
      let(:user) { create(:user) }

      before do
        allow(controller).to receive(:api_user).and_return(user)
      end

      it "handles initialize request" do
        request_body = {
          jsonrpc: "2.0",
          id: 1,
          method: "initialize",
          params: {}
        }.to_json

        post :execute, format: :json, body: request_body

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["result"]["protocolVersion"]).to eq("2024-11-05")
        expect(json["result"]["serverInfo"]["name"]).to eq("serveme-mcp")
        expect(json["result"]["capabilities"]).to have_key("tools")
      end

      it "handles initialized notification with no content" do
        request_body = {
          jsonrpc: "2.0",
          method: "initialized"
        }.to_json

        post :execute, format: :json, body: request_body

        expect(response).to have_http_status(:no_content)
      end

      it "can list public tools" do
        request_body = {
          jsonrpc: "2.0",
          id: 1,
          method: "tools/list"
        }.to_json

        post :execute, format: :json, body: request_body

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        tool_names = json["result"]["tools"].map { |t| t["name"] }
        expect(tool_names).to include("get_public_servers")
        expect(tool_names).not_to include("search_alts")
      end

      it "can call public tools" do
        request_body = {
          jsonrpc: "2.0",
          id: 2,
          method: "tools/call",
          params: {
            name: "get_public_servers",
            arguments: {}
          }
        }.to_json

        post :execute, format: :json, body: request_body

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["result"]["content"]).to be_an(Array)
      end

      it "returns permission error for admin tools" do
        request_body = {
          jsonrpc: "2.0",
          id: 3,
          method: "tools/call",
          params: {
            name: "search_alts",
            arguments: { query: "test" }
          }
        }.to_json

        post :execute, format: :json, body: request_body

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["error"]).to be_present
        expect(json["error"]["message"]).to include("permission")
      end
    end

    context "with admin user" do
      let(:admin) { create(:user, :admin) }

      before do
        allow(controller).to receive(:api_user).and_return(admin)
      end

      it "handles tools/list request" do
        request_body = {
          jsonrpc: "2.0",
          id: 1,
          method: "tools/list"
        }.to_json

        post :execute, format: :json, body: request_body

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["jsonrpc"]).to eq("2.0")
        expect(json["id"]).to eq(1)
        expect(json["result"]["tools"]).to be_an(Array)
      end

      it "handles tools/call request" do
        request_body = {
          jsonrpc: "2.0",
          id: 2,
          method: "tools/call",
          params: {
            name: "list_servers",
            arguments: {}
          }
        }.to_json

        post :execute, format: :json, body: request_body

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["jsonrpc"]).to eq("2.0")
        expect(json["id"]).to eq(2)
        expect(json["result"]["content"]).to be_an(Array)
      end

      it "returns error for unknown tool" do
        request_body = {
          jsonrpc: "2.0",
          id: 3,
          method: "tools/call",
          params: {
            name: "unknown_tool",
            arguments: {}
          }
        }.to_json

        post :execute, format: :json, body: request_body

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["error"]).to be_present
        expect(json["error"]["code"]).to eq(-32601)
      end

      it "returns error for invalid JSON" do
        post :execute, format: :json, body: "not valid json"

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq(-32700)
      end
    end

    context "with league admin accessing admin-only tool" do
      let(:league_admin) do
        user = create(:user)
        user.groups << Group.league_admin_group
        user
      end

      before do
        allow(controller).to receive(:api_user).and_return(league_admin)
      end

      it "returns permission error" do
        request_body = {
          jsonrpc: "2.0",
          id: 4,
          method: "tools/call",
          params: {
            name: "get_user",
            arguments: { query: "test" }
          }
        }.to_json

        post :execute, format: :json, body: request_body

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["error"]).to be_present
        expect(json["error"]["message"]).to include("permission")
      end
    end
  end
end
