# typed: false

require "spec_helper"
require "webmock/rspec"

RSpec.describe CloudProvider::Kamatera do
  subject(:provider) { described_class.new }

  let(:client_id) { "test-kamatera-client-id" }
  let(:client_secret) { "test-kamatera-secret" }
  let(:auth_headers) { { "AuthClientId" => client_id, "AuthSecret" => client_secret } }

  before do
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig)
      .with(:cloud_servers, :kamatera, :access_key)
      .and_return(client_id)
    allow(Rails.application.credentials).to receive(:dig)
      .with(:cloud_servers, :kamatera, :secret_key)
      .and_return(client_secret)
  end

  describe "#server_status" do
    context "when server is powered on" do
      before do
        stub_request(:get, "https://console.kamatera.com/service/server/uuid-abc-123")
          .with(headers: auth_headers)
          .to_return(status: 200, body: { power: "on", name: "serveme-42" }.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "returns 'running'" do
        VCR.turned_off { expect(provider.server_status("uuid-abc-123")).to eq("running") }
      end
    end

    context "when server is powered off" do
      before do
        stub_request(:get, "https://console.kamatera.com/service/server/uuid-abc-123")
          .with(headers: auth_headers)
          .to_return(status: 200, body: { power: "off", name: "serveme-42" }.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "returns 'stopped'" do
        VCR.turned_off { expect(provider.server_status("uuid-abc-123")).to eq("stopped") }
      end
    end

    context "when server is not found" do
      before do
        stub_request(:get, "https://console.kamatera.com/service/server/uuid-abc-123")
          .with(headers: auth_headers)
          .to_return(status: 404)
      end

      it "returns 'provisioning'" do
        VCR.turned_off { expect(provider.server_status("uuid-abc-123")).to eq("provisioning") }
      end
    end
  end

  describe "#server_ip" do
    before do
      stub_request(:get, "https://console.kamatera.com/service/server/uuid-abc-123")
        .with(headers: auth_headers)
        .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })
    end

    context "when IP is assigned" do
      let(:response_body) do
        { name: "serveme-42", networks: [ { network: "wan-as", ips: [ "103.45.67.89" ] } ] }.to_json
      end

      it "returns the IP address" do
        VCR.turned_off { expect(provider.server_ip("uuid-abc-123")).to eq("103.45.67.89") }
      end
    end

    context "when no networks" do
      let(:response_body) do
        { name: "serveme-42", networks: [] }.to_json
      end

      it "returns nil" do
        VCR.turned_off { expect(provider.server_ip("uuid-abc-123")).to be_nil }
      end
    end
  end

  describe "#destroy_server" do
    before do
      stub_request(:delete, "https://console.kamatera.com/service/server/uuid-abc-123/terminate")
        .with(headers: auth_headers)
        .to_return(status: response_status, body: "12345", headers: { "Content-Type" => "application/json" })
    end

    context "when deletion succeeds" do
      let(:response_status) { 200 }

      it "returns true" do
        VCR.turned_off { expect(provider.destroy_server("uuid-abc-123")).to be true }
      end
    end

    context "when deletion fails" do
      let(:response_status) { 404 }

      it "returns false" do
        VCR.turned_off { expect(provider.destroy_server("uuid-abc-123")).to be false }
      end
    end
  end

  describe "#destroy_servers_by_label" do
    it "lists servers and destroys matching ones" do
      stub_request(:get, "https://console.kamatera.com/service/servers")
        .with(headers: auth_headers)
        .to_return(status: 200, body: [
          { id: "uuid-abc-123", name: "serveme-42" },
          { id: "uuid-def-456", name: "other-server" }
        ].to_json, headers: { "Content-Type" => "application/json" })

      stub_request(:delete, "https://console.kamatera.com/service/server/uuid-abc-123/terminate")
        .to_return(status: 200, body: "12345")

      VCR.turned_off { expect(provider.destroy_servers_by_label("serveme-42")).to eq(1) }
    end

    it "returns 0 when no servers match" do
      stub_request(:get, "https://console.kamatera.com/service/servers")
        .with(headers: auth_headers)
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      VCR.turned_off { expect(provider.destroy_servers_by_label("serveme-99")).to eq(0) }
    end
  end
end
