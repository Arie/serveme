# typed: false

require "spec_helper"
require "webmock/rspec"

RSpec.describe CloudProvider::Kamatera do
  subject(:provider) { described_class.new }

  let(:client_id) { "test-kamatera-client-id" }
  let(:client_secret) { "test-kamatera-secret" }
  let(:auth_token) { "test-auth-token-abc123" }

  before do
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig)
      .with(:cloud_servers, :kamatera, :access_key)
      .and_return(client_id)
    allow(Rails.application.credentials).to receive(:dig)
      .with(:cloud_servers, :kamatera, :secret_key)
      .and_return(client_secret)

    stub_request(:post, "https://console.kamatera.com/service/authenticate")
      .with(body: { clientId: client_id, secret: client_secret }.to_json)
      .to_return(status: 200, body: { authentication: auth_token, expires: 1.hour.from_now.to_i }.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  describe "#server_status" do
    context "when server is powered on" do
      before do
        stub_request(:get, "https://console.kamatera.com/service/server/serveme-42")
          .with(headers: { "Authorization" => "Bearer #{auth_token}" })
          .to_return(status: 200, body: { power: "on", name: "serveme-42" }.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "returns 'running'" do
        VCR.turned_off { expect(provider.server_status("serveme-42")).to eq("running") }
      end
    end

    context "when server is powered off" do
      before do
        stub_request(:get, "https://console.kamatera.com/service/server/serveme-42")
          .with(headers: { "Authorization" => "Bearer #{auth_token}" })
          .to_return(status: 200, body: { power: "off", name: "serveme-42" }.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "returns 'stopped'" do
        VCR.turned_off { expect(provider.server_status("serveme-42")).to eq("stopped") }
      end
    end

    context "when server is not found" do
      before do
        stub_request(:get, "https://console.kamatera.com/service/server/serveme-99")
          .with(headers: { "Authorization" => "Bearer #{auth_token}" })
          .to_return(status: 404)
      end

      it "returns 'provisioning'" do
        VCR.turned_off { expect(provider.server_status("serveme-99")).to eq("provisioning") }
      end
    end
  end

  describe "#server_ip" do
    before do
      stub_request(:get, "https://console.kamatera.com/service/server/serveme-42")
        .with(headers: { "Authorization" => "Bearer #{auth_token}" })
        .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })
    end

    context "when IP is assigned" do
      let(:response_body) do
        { name: "serveme-42", networks: [ { network: "wan-as", ips: [ "103.45.67.89" ] } ] }.to_json
      end

      it "returns the IP address" do
        VCR.turned_off { expect(provider.server_ip("serveme-42")).to eq("103.45.67.89") }
      end
    end

    context "when no networks" do
      let(:response_body) do
        { name: "serveme-42", networks: [] }.to_json
      end

      it "returns nil" do
        VCR.turned_off { expect(provider.server_ip("serveme-42")).to be_nil }
      end
    end
  end

  describe "#destroy_server" do
    before do
      stub_request(:delete, "https://console.kamatera.com/service/server/serveme-42/terminate")
        .with(headers: { "Authorization" => "Bearer #{auth_token}" })
        .to_return(status: response_status, body: "12345", headers: { "Content-Type" => "application/json" })
    end

    context "when deletion succeeds" do
      let(:response_status) { 200 }

      it "returns true" do
        VCR.turned_off { expect(provider.destroy_server("serveme-42")).to be true }
      end
    end

    context "when deletion fails" do
      let(:response_status) { 404 }

      it "returns false" do
        VCR.turned_off { expect(provider.destroy_server("serveme-42")).to be false }
      end
    end
  end

  describe "#destroy_servers_by_label" do
    it "lists servers and destroys matching ones" do
      stub_request(:get, "https://console.kamatera.com/service/servers")
        .with(headers: { "Authorization" => "Bearer #{auth_token}" })
        .to_return(status: 200, body: [
          { name: "serveme-42" },
          { name: "other-server" }
        ].to_json, headers: { "Content-Type" => "application/json" })

      stub_request(:delete, "https://console.kamatera.com/service/server/serveme-42/terminate")
        .to_return(status: 200, body: "12345")

      VCR.turned_off { expect(provider.destroy_servers_by_label("serveme-42")).to eq(1) }
    end

    it "returns 0 when no servers match" do
      stub_request(:get, "https://console.kamatera.com/service/servers")
        .with(headers: { "Authorization" => "Bearer #{auth_token}" })
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      VCR.turned_off { expect(provider.destroy_servers_by_label("serveme-99")).to eq(0) }
    end
  end
end
