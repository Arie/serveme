# typed: false

require "spec_helper"
require "webmock/rspec"

RSpec.describe CloudProvider::Vultr do
  subject(:provider) { described_class.new }

  let(:api_token) { "test-vultr-token" }

  before do
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig)
      .with(:cloud_servers, :vultr, :api_key)
      .and_return(api_token)
  end

  describe "#create_server" do
    let(:cloud_server) { create(:cloud_server, cloud_provider: "vultr", cloud_location: "ewr") }
    let(:response_body) do
      { instance: { id: "cb676a46-66fd-4dfb-b839-443f2e6c0b60", status: "pending" } }.to_json
    end

    before do
      allow(Rails.application.credentials).to receive(:dig)
        .with(:cloud_servers, :vultr, :ssh_key_id)
        .and_return("ssh-key-id-123")
      allow(Rails.application.credentials).to receive(:dig)
        .with(:cloud_servers, :callback_token)
        .and_return("test-callback-token")
      allow(Rails.application.credentials).to receive(:dig)
        .with(:cloud_servers, :ssh_public_key)
        .and_return("ssh-ed25519 AAAA test@serveme")

      stub_request(:post, "https://api.vultr.com/v2/instances")
        .with(headers: { "Authorization" => "Bearer #{api_token}" })
        .to_return(status: 202, body: response_body, headers: { "Content-Type" => "application/json" })
    end

    context "without snapshot_id" do
      before do
        allow(Rails.application.credentials).to receive(:dig)
          .with(:cloud_servers, :vultr, :snapshot_id)
          .and_return(nil)
      end

      it "POSTs with image_id and returns the instance ID" do
        VCR.turned_off do
          result = provider.create_server(cloud_server)

          expect(result).to eq("cb676a46-66fd-4dfb-b839-443f2e6c0b60")
          expect(WebMock).to have_requested(:post, "https://api.vultr.com/v2/instances")
            .with { |req|
              body = JSON.parse(req.body)
              body["label"] == provider.cloud_server_name(cloud_server) &&
                body["plan"] == "vc2-2c-2gb" &&
                body["region"] == "ewr" &&
                body["image_id"] == "docker" &&
                !body.key?("snapshot_id")
            }
        end
      end
    end

    context "with snapshot_id" do
      before do
        allow(Rails.application.credentials).to receive(:dig)
          .with(:cloud_servers, :vultr, :snapshot_id)
          .and_return("snap-abc-123")
      end

      it "POSTs with snapshot_id instead of app_id" do
        VCR.turned_off do
          result = provider.create_server(cloud_server)

          expect(result).to eq("cb676a46-66fd-4dfb-b839-443f2e6c0b60")
          expect(WebMock).to have_requested(:post, "https://api.vultr.com/v2/instances")
            .with { |req|
              body = JSON.parse(req.body)
              body["label"] == provider.cloud_server_name(cloud_server) &&
                body["plan"] == "vc2-2c-2gb" &&
                body["region"] == "ewr" &&
                body["snapshot_id"] == "snap-abc-123" &&
                !body.key?("image_id")
            }
        end
      end
    end
  end

  describe "#server_status" do
    before do
      stub_request(:get, "https://api.vultr.com/v2/instances/abc-123")
        .with(headers: { "Authorization" => "Bearer #{api_token}" })
        .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })
    end

    context "when instance is pending" do
      let(:response_body) { { instance: { status: "pending", power_status: "stopped" } }.to_json }

      it "returns 'provisioning'" do
        VCR.turned_off { expect(provider.server_status("abc-123")).to eq("provisioning") }
      end
    end

    context "when instance is active and running" do
      let(:response_body) { { instance: { status: "active", power_status: "running" } }.to_json }

      it "returns 'running'" do
        VCR.turned_off { expect(provider.server_status("abc-123")).to eq("running") }
      end
    end

    context "when instance is active but stopped" do
      let(:response_body) { { instance: { status: "active", power_status: "stopped" } }.to_json }

      it "returns 'stopped'" do
        VCR.turned_off { expect(provider.server_status("abc-123")).to eq("stopped") }
      end
    end

    context "when instance is suspended" do
      let(:response_body) { { instance: { status: "suspended", power_status: "stopped" } }.to_json }

      it "returns 'stopped'" do
        VCR.turned_off { expect(provider.server_status("abc-123")).to eq("stopped") }
      end
    end

    context "when instance is halted" do
      let(:response_body) { { instance: { status: "halted", power_status: "stopped" } }.to_json }

      it "returns 'stopped'" do
        VCR.turned_off { expect(provider.server_status("abc-123")).to eq("stopped") }
      end
    end
  end

  describe "#server_ip" do
    before do
      stub_request(:get, "https://api.vultr.com/v2/instances/abc-123")
        .with(headers: { "Authorization" => "Bearer #{api_token}" })
        .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })
    end

    context "when IP is assigned" do
      let(:response_body) do
        { instance: { main_ip: "45.76.1.2" } }.to_json
      end

      it "returns the IP address" do
        VCR.turned_off { expect(provider.server_ip("abc-123")).to eq("45.76.1.2") }
      end
    end

    context "when IP is not yet assigned" do
      let(:response_body) do
        { instance: { main_ip: "0.0.0.0" } }.to_json
      end

      it "returns nil" do
        VCR.turned_off { expect(provider.server_ip("abc-123")).to be_nil }
      end
    end
  end

  describe "#destroy_server" do
    before do
      stub_request(:delete, "https://api.vultr.com/v2/instances/abc-123")
        .with(headers: { "Authorization" => "Bearer #{api_token}" })
        .to_return(status: response_status)
    end

    context "when deletion succeeds" do
      let(:response_status) { 204 }

      it "returns true" do
        VCR.turned_off { expect(provider.destroy_server("abc-123")).to be true }
      end
    end

    context "when deletion fails" do
      let(:response_status) { 404 }

      it "returns false" do
        VCR.turned_off { expect(provider.destroy_server("abc-123")).to be false }
      end
    end
  end

  describe "#destroy_servers_by_label" do
    it "lists instances by label and destroys each one" do
      stub_request(:get, "https://api.vultr.com/v2/instances?label=serveme-42")
        .with(headers: { "Authorization" => "Bearer #{api_token}" })
        .to_return(status: 200, body: {
          instances: [
            { id: "aaa-111" },
            { id: "bbb-222" }
          ]
        }.to_json, headers: { "Content-Type" => "application/json" })

      stub_request(:delete, "https://api.vultr.com/v2/instances/aaa-111")
        .to_return(status: 204)
      stub_request(:delete, "https://api.vultr.com/v2/instances/bbb-222")
        .to_return(status: 204)

      VCR.turned_off { expect(provider.destroy_servers_by_label("serveme-42")).to eq(2) }
    end

    it "returns 0 when no instances match" do
      stub_request(:get, "https://api.vultr.com/v2/instances?label=serveme-99")
        .with(headers: { "Authorization" => "Bearer #{api_token}" })
        .to_return(status: 200, body: { instances: [] }.to_json, headers: { "Content-Type" => "application/json" })

      VCR.turned_off { expect(provider.destroy_servers_by_label("serveme-99")).to eq(0) }
    end
  end

  describe "#cloud_init_docker_pull (private)" do
    let(:cloud_server) { build_stubbed(:cloud_server, cloud_location: "blr") }
    let(:image) { "serveme/tf2-cloud-server:latest" }

    it "wraps mirror pulls in a 90s timeout and the upstream pull in a 300s timeout" do
      script = provider.send(:cloud_init_docker_pull, cloud_server, image)

      expect(script).to match(%r{timeout --kill-after=10s 90s docker pull blr\.vultrcr\.com/docker\.io/serveme/tf2-cloud-server:latest})
      expect(script).to match(%r{timeout --kill-after=10s 300s docker pull serveme/tf2-cloud-server:latest})
    end
  end
end
