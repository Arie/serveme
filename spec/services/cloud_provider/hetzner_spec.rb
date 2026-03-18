# typed: false

require "spec_helper"
require "webmock/rspec"

RSpec.describe CloudProvider::Hetzner do
  subject(:provider) { described_class.new }

  let(:api_token) { "test-hetzner-token" }

  before do
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig)
      .with(:cloud_servers, :hetzner, :api_key)
      .and_return(api_token)
  end

  describe "#create_server" do
    let(:cloud_server) { create(:cloud_server, cloud_location: "fsn1") }
    let(:response_body) do
      { server: { id: 12345, status: "initializing" } }.to_json
    end

    before do
      allow(Rails.application.credentials).to receive(:dig)
        .with(:cloud_servers, :hetzner, :image_id)
        .and_return("docker-ce")
      allow(Rails.application.credentials).to receive(:dig)
        .with(:cloud_servers, :hetzner, :ssh_key_name)
        .and_return("serveme-cloud")
      allow(Rails.application.credentials).to receive(:dig)
        .with(:cloud_servers, :callback_token)
        .and_return("test-callback-token")
      allow(Rails.application.credentials).to receive(:dig)
        .with(:cloud_servers, :ssh_public_key)
        .and_return("ssh-ed25519 AAAA test@serveme")
      stub_request(:post, "https://api.hetzner.cloud/v1/servers")
        .with(headers: { "Authorization" => "Bearer #{api_token}" })
        .to_return(status: 201, body: response_body, headers: { "Content-Type" => "application/json" })

      stub_request(:get, "https://api.hetzner.cloud/v1/images?page=1&per_page=50&sort=created:desc&type=snapshot")
        .with(headers: { "Authorization" => "Bearer #{api_token}" })
        .to_return(status: 200, body: {
          images: [ { id: 361302880, description: "serveme-cloud-20260224", status: "available" } ],
          meta: { pagination: { last_page: 1 } }
        }.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "POSTs to the Hetzner API and returns the server ID" do
      VCR.turned_off do
        result = provider.create_server(cloud_server)

        expect(result).to eq("12345")
        expect(WebMock).to have_requested(:post, "https://api.hetzner.cloud/v1/servers")
          .with { |req|
            body = JSON.parse(req.body)
            body["name"] == provider.cloud_server_name(cloud_server) &&
              body["server_type"] == "cpx22" &&
              body["location"] == "fsn1"
          }
      end
    end
  end

  describe "#server_status" do
    before do
      stub_request(:get, "https://api.hetzner.cloud/v1/servers/12345")
        .with(headers: { "Authorization" => "Bearer #{api_token}" })
        .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })
    end

    context "when server is initializing" do
      let(:response_body) { { server: { status: "initializing" } }.to_json }

      it "returns 'provisioning'" do
        VCR.turned_off { expect(provider.server_status("12345")).to eq("provisioning") }
      end
    end

    context "when server is starting" do
      let(:response_body) { { server: { status: "starting" } }.to_json }

      it "returns 'provisioning'" do
        VCR.turned_off { expect(provider.server_status("12345")).to eq("provisioning") }
      end
    end

    context "when server is running" do
      let(:response_body) { { server: { status: "running" } }.to_json }

      it "returns 'running'" do
        VCR.turned_off { expect(provider.server_status("12345")).to eq("running") }
      end
    end

    context "when server is stopping" do
      let(:response_body) { { server: { status: "stopping" } }.to_json }

      it "returns 'stopped'" do
        VCR.turned_off { expect(provider.server_status("12345")).to eq("stopped") }
      end
    end

    context "when server is off" do
      let(:response_body) { { server: { status: "off" } }.to_json }

      it "returns 'stopped'" do
        VCR.turned_off { expect(provider.server_status("12345")).to eq("stopped") }
      end
    end
  end

  describe "#server_ip" do
    let(:response_body) do
      { server: { public_net: { ipv4: { ip: "1.2.3.4" } } } }.to_json
    end

    before do
      stub_request(:get, "https://api.hetzner.cloud/v1/servers/12345")
        .with(headers: { "Authorization" => "Bearer #{api_token}" })
        .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })
    end

    it "extracts the IPv4 address from the response" do
      VCR.turned_off { expect(provider.server_ip("12345")).to eq("1.2.3.4") }
    end
  end

  describe "#destroy_server" do
    before do
      stub_request(:delete, "https://api.hetzner.cloud/v1/servers/12345")
        .with(headers: { "Authorization" => "Bearer #{api_token}" })
        .to_return(status: response_status)
    end

    context "when deletion succeeds" do
      let(:response_status) { 200 }

      it "returns true" do
        VCR.turned_off { expect(provider.destroy_server("12345")).to be true }
      end
    end

    context "when deletion fails" do
      let(:response_status) { 404 }

      it "returns false" do
        VCR.turned_off { expect(provider.destroy_server("12345")).to be false }
      end
    end
  end

  describe "#destroy_servers_by_label" do
    it "lists servers by name and destroys each one" do
      stub_request(:get, "https://api.hetzner.cloud/v1/servers?name=serveme-42")
        .with(headers: { "Authorization" => "Bearer #{api_token}" })
        .to_return(status: 200, body: {
          servers: [
            { id: 111 },
            { id: 222 }
          ]
        }.to_json, headers: { "Content-Type" => "application/json" })

      stub_request(:delete, "https://api.hetzner.cloud/v1/servers/111")
        .to_return(status: 200)
      stub_request(:delete, "https://api.hetzner.cloud/v1/servers/222")
        .to_return(status: 200)

      VCR.turned_off { expect(provider.destroy_servers_by_label("serveme-42")).to eq(2) }
    end

    it "returns 0 when no servers match" do
      stub_request(:get, "https://api.hetzner.cloud/v1/servers?name=serveme-99")
        .with(headers: { "Authorization" => "Bearer #{api_token}" })
        .to_return(status: 200, body: { servers: [] }.to_json, headers: { "Content-Type" => "application/json" })

      VCR.turned_off { expect(provider.destroy_servers_by_label("serveme-99")).to eq(0) }
    end
  end
end
