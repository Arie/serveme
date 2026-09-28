# typed: false
# frozen_string_literal: true

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

  describe "#create_server" do
    let(:cloud_server) { create(:cloud_server, cloud_location: "EU-FR") }
    let(:create_status) { 200 }
    let(:create_body) { [ "cmd-555" ].to_json }

    before do
      allow(Rails.application.credentials).to receive(:dig)
        .with(:cloud_servers, :callback_token)
        .and_return("test-callback-token")
      allow(Rails.application.credentials).to receive(:dig)
        .with(:cloud_servers, :ssh_public_key)
        .and_return("ssh-ed25519 AAAA test@serveme")
      stub_request(:post, "https://console.kamatera.com/svc/serverCreate")
        .with(headers: auth_headers.merge("Content-Type" => "application/json", "Accept" => "application/json"))
        .to_return(status: create_status, body: create_body, headers: { "Content-Type" => "application/json" })
    end

    it "POSTs the server spec and returns the prefixed command ID" do
      VCR.turned_off do
        expect(provider.create_server(cloud_server)).to eq("cmd:cmd-555")

        expect(WebMock).to have_requested(:post, "https://console.kamatera.com/svc/serverCreate")
          .with { |req|
            body = JSON.parse(req.body)
            body["datacenter"] == "EU-FR" &&
              body["names"] == [ provider.cloud_server_name(cloud_server) ] &&
              body["cpuStr"] == "2B" && body["cpuType"] == "B" &&
              body["ramMB"] == 2048 && body["diskSizesGB"] == [ 20 ] &&
              body["trafficPackage"] == "t5000" &&
              body["diskImageId"] == "EU-FR:6000C29549da189eaef6ea8a31001a34" &&
              body["selectedSSHKeyValue"] == "ssh-ed25519 AAAA test@serveme" &&
              body["script"].start_with?("#!/bin/bash") &&
              body["password"].match?(/\ASv\h{16}!\z/) &&
              body["password"] == body["passwordValidate"]
          }
      end
    end

    context "when the API returns a single command ID instead of an array" do
      let(:create_body) { "cmd-777".to_json }

      it "wraps it and returns the prefixed ID" do
        VCR.turned_off { expect(provider.create_server(cloud_server)).to eq("cmd:cmd-777") }
      end
    end

    context "when the cloud server has no location" do
      let(:cloud_server) { create(:cloud_server, cloud_location: nil) }

      it "falls back to Hong Kong (AS)" do
        VCR.turned_off do
          provider.create_server(cloud_server)

          expect(WebMock).to have_requested(:post, "https://console.kamatera.com/svc/serverCreate")
            .with { |req|
              body = JSON.parse(req.body)
              body["datacenter"] == "AS" && body["diskImageId"].start_with?("AS:")
            }
        end
      end
    end

    context "when the API returns an error" do
      let(:create_status) { 400 }
      let(:create_body) { { error: "Insufficient balance" }.to_json }

      it "raises with the API error message" do
        VCR.turned_off do
          expect { provider.create_server(cloud_server) }
            .to raise_error(RuntimeError, "Kamatera API error (400): Insufficient balance")
        end
      end
    end
  end

  describe "#find_server_by_label" do
    it "returns the UUID of the server with a matching name" do
      stub_request(:get, "https://console.kamatera.com/service/servers")
        .with(headers: auth_headers)
        .to_return(status: 200, body: [
          { id: "uuid-def-456", name: "other-server" },
          { id: "uuid-abc-123", name: "serveme-eu-42" }
        ].to_json)

      VCR.turned_off { expect(provider.find_server_by_label("serveme-eu-42")).to eq("uuid-abc-123") }
    end

    it "returns nil when no server matches" do
      stub_request(:get, "https://console.kamatera.com/service/servers")
        .to_return(status: 200, body: [ { id: "uuid-def-456", name: "other-server" } ].to_json)

      VCR.turned_off { expect(provider.find_server_by_label("serveme-eu-42")).to be_nil }
    end

    it "returns nil when the listing is not an array" do
      stub_request(:get, "https://console.kamatera.com/service/servers")
        .to_return(status: 200, body: { error: "weird" }.to_json)

      VCR.turned_off { expect(provider.find_server_by_label("serveme-eu-42")).to be_nil }
    end

    it "returns nil when the listing request fails" do
      stub_request(:get, "https://console.kamatera.com/service/servers")
        .to_return(status: 500, body: "")

      VCR.turned_off { expect(provider.find_server_by_label("serveme-eu-42")).to be_nil }
    end
  end

  describe "#pending_command?" do
    it "is true for cmd: prefixed IDs" do
      expect(provider.pending_command?("cmd:123")).to be true
    end

    it "is false for resolved UUIDs" do
      expect(provider.pending_command?("uuid-abc-123")).to be false
    end

    it "is false for nil" do
      expect(provider.pending_command?(nil)).to be false
    end
  end

  describe "#poll_command" do
    let(:cloud_server) { create(:cloud_server, cloud_provider_id: "cmd:cmd-555") }
    let(:server_name) { provider.cloud_server_name(cloud_server) }
    let(:queue_status) { 200 }

    before do
      stub_request(:get, "https://console.kamatera.com/service/queue/cmd-555")
        .with(headers: auth_headers)
        .to_return(status: queue_status, body: queue_body)
    end

    context "when the command is complete" do
      let(:queue_body) { { status: "complete" }.to_json }

      it "resolves the server UUID by name" do
        stub_request(:get, "https://console.kamatera.com/service/servers")
          .to_return(status: 200, body: [ { id: "uuid-abc-123", name: server_name } ].to_json)

        VCR.turned_off { expect(provider.poll_command(cloud_server)).to eq("uuid-abc-123") }
      end

      it "raises when the created server cannot be found" do
        stub_request(:get, "https://console.kamatera.com/service/servers")
          .to_return(status: 200, body: [].to_json)

        VCR.turned_off do
          expect { provider.poll_command(cloud_server) }
            .to raise_error(RuntimeError, "Kamatera server created but UUID not found")
        end
      end
    end

    context "when the command errored" do
      let(:queue_body) { { status: "error", log: "No capacity in datacenter" }.to_json }

      it "raises with the command log" do
        VCR.turned_off do
          expect { provider.poll_command(cloud_server) }
            .to raise_error(RuntimeError, "Kamatera server creation failed: No capacity in datacenter")
        end
      end
    end

    context "when the command was cancelled" do
      let(:queue_body) { { status: "cancelled" }.to_json }

      it "raises" do
        VCR.turned_off do
          expect { provider.poll_command(cloud_server) }
            .to raise_error(RuntimeError, "Kamatera server creation cancelled")
        end
      end
    end

    context "when the command is still in progress" do
      let(:queue_body) { { status: "progress" }.to_json }

      it "returns nil" do
        VCR.turned_off { expect(provider.poll_command(cloud_server)).to be_nil }
      end
    end

    context "when the queue response is not a hash" do
      let(:queue_body) { [ "unexpected" ].to_json }

      it "returns nil" do
        VCR.turned_off { expect(provider.poll_command(cloud_server)).to be_nil }
      end
    end

    context "when the queue request fails" do
      let(:queue_status) { 503 }
      let(:queue_body) { "" }

      it "returns nil" do
        VCR.turned_off { expect(provider.poll_command(cloud_server)).to be_nil }
      end
    end
  end

  describe "#server_status with unknown power state" do
    it "returns 'provisioning'" do
      stub_request(:get, "https://console.kamatera.com/service/server/uuid-abc-123")
        .to_return(status: 200, body: { name: "serveme-42" }.to_json)

      VCR.turned_off { expect(provider.server_status("uuid-abc-123")).to eq("provisioning") }
    end
  end

  describe "#server_ip edge cases" do
    it "returns nil when the request fails" do
      stub_request(:get, "https://console.kamatera.com/service/server/uuid-abc-123")
        .to_return(status: 500, body: "")

      VCR.turned_off { expect(provider.server_ip("uuid-abc-123")).to be_nil }
    end

    it "ignores LAN networks and missing network keys" do
      stub_request(:get, "https://console.kamatera.com/service/server/uuid-abc-123")
        .to_return(status: 200, body: { networks: [ { ips: [ "1.1.1.1" ] }, { network: "lan-1", ips: [ "10.0.0.2" ] } ] }.to_json)

      VCR.turned_off { expect(provider.server_ip("uuid-abc-123")).to be_nil }
    end
  end

  describe "#destroy_servers_by_label edge cases" do
    it "sends confirm and force flags form-encoded" do
      stub_request(:get, "https://console.kamatera.com/service/servers")
        .to_return(status: 200, body: [ { id: "uuid-abc-123", name: "serveme-42" } ].to_json)
      stub_request(:delete, "https://console.kamatera.com/service/server/uuid-abc-123/terminate")
        .with(body: "confirm=1&force=1", headers: { "Content-Type" => "application/x-www-form-urlencoded" })
        .to_return(status: 200, body: "12345")

      VCR.turned_off { expect(provider.destroy_servers_by_label("serveme-42")).to eq(1) }
    end

    it "does not count servers whose termination failed" do
      stub_request(:get, "https://console.kamatera.com/service/servers")
        .to_return(status: 200, body: [ { id: "uuid-abc-123", name: "serveme-42" } ].to_json)
      stub_request(:delete, "https://console.kamatera.com/service/server/uuid-abc-123/terminate")
        .to_return(status: 500, body: "")

      VCR.turned_off { expect(provider.destroy_servers_by_label("serveme-42")).to eq(0) }
    end

    it "returns 0 when the listing request fails" do
      stub_request(:get, "https://console.kamatera.com/service/servers")
        .to_return(status: 500, body: "")

      VCR.turned_off { expect(provider.destroy_servers_by_label("serveme-42")).to eq(0) }
    end

    it "returns 0 when the listing is not an array" do
      stub_request(:get, "https://console.kamatera.com/service/servers")
        .to_return(status: 200, body: { servers: [] }.to_json)

      VCR.turned_off { expect(provider.destroy_servers_by_label("serveme-42")).to eq(0) }
    end
  end

  describe "credentials" do
    it "prefers the KAMATERA_* environment variables over credentials" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("KAMATERA_CLIENT_ID").and_return("env-id")
      allow(ENV).to receive(:[]).with("KAMATERA_SECRET").and_return("env-secret")
      stub_request(:get, "https://console.kamatera.com/service/server/uuid-abc-123")
        .with(headers: { "AuthClientId" => "env-id", "AuthSecret" => "env-secret" })
        .to_return(status: 200, body: { power: "on" }.to_json)

      VCR.turned_off { expect(provider.server_status("uuid-abc-123")).to eq("running") }
    end
  end

  describe "static metadata" do
    it "lists the provisioning phases in order" do
      expect(provider.provision_phases.map { |p| p[:key] })
        .to eq(%w[creating_vm booting configuring booting_tf2 starting_tf2])
      expect(provider.provision_phases.sum { |p| p[:seconds] }).to eq(230)
    end

    it "estimates about 4 minutes" do
      expect(provider.estimated_provision_time).to eq("about 4 minutes")
    end

    it "uses the kamatera snapshot credential key" do
      expect(provider.snapshot_credential_key).to eq("cloud_servers.kamatera.snapshot_id")
    end
  end

  describe "unimplemented snapshot operations" do
    it "raises NotImplementedError for create_snapshot_server" do
      expect { provider.create_snapshot_server("AS", "#!/bin/bash") }
        .to raise_error(NotImplementedError, /snapshot creation not yet implemented/)
    end

    it "raises NotImplementedError for halt_server" do
      expect { provider.halt_server("uuid-abc-123") }.to raise_error(NotImplementedError, /halt not yet implemented/)
    end

    it "raises NotImplementedError for create_snapshot" do
      expect { provider.create_snapshot("uuid-abc-123", "desc") }.to raise_error(NotImplementedError, /snapshots not yet implemented/)
    end

    it "raises NotImplementedError for wait_for_snapshot" do
      expect { provider.wait_for_snapshot("snap-1") }.to raise_error(NotImplementedError, /snapshots not yet implemented/)
    end
  end
end
