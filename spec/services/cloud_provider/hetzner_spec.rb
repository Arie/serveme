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

    it "boots from the newest serveme snapshot with the configured ssh key" do
      VCR.turned_off do
        provider.create_server(cloud_server)

        expect(WebMock).to have_requested(:post, "https://api.hetzner.cloud/v1/servers")
          .with { |req|
            body = JSON.parse(req.body)
            body["image"] == "361302880" && body["ssh_keys"] == [ "serveme-cloud" ] && body["user_data"].present?
          }
      end
    end

    context "when the cloud server has no location" do
      let(:cloud_server) { create(:cloud_server, cloud_location: nil) }

      it "falls back to fsn1" do
        VCR.turned_off do
          provider.create_server(cloud_server)

          expect(WebMock).to have_requested(:post, "https://api.hetzner.cloud/v1/servers")
            .with { |req| JSON.parse(req.body).values_at("location", "server_type") == [ "fsn1", "cpx22" ] }
        end
      end
    end

    context "when the API returns 2xx without a server id" do
      let(:response_body) { { error: { message: "maintenance" } }.to_json }

      it "raises instead of storing an empty string as the provider ID" do
        VCR.turned_off do
          expect { provider.create_server(cloud_server) }
            .to raise_error(/Hetzner API returned no server id/)
        end
      end
    end
  end

  describe "#find_server_by_label" do
    it "returns the oldest server carrying the name" do
      stub_request(:get, "https://api.hetzner.cloud/v1/servers?name=serveme-42")
        .with(headers: { "Authorization" => "Bearer #{api_token}" })
        .to_return(status: 200, body: {
          servers: [
            { id: 222, created: "2026-08-03T19:13:01+00:00" },
            { id: 111, created: "2026-08-03T19:11:25+00:00" }
          ]
        }.to_json, headers: { "Content-Type" => "application/json" })

      VCR.turned_off { expect(provider.find_server_by_label("serveme-42")).to eq("111") }
    end

    it "returns nil when nothing carries the name" do
      stub_request(:get, "https://api.hetzner.cloud/v1/servers?name=serveme-99")
        .to_return(status: 200, body: { servers: [] }.to_json, headers: { "Content-Type" => "application/json" })

      VCR.turned_off { expect(provider.find_server_by_label("serveme-99")).to be_nil }
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

    context "when server status is unknown" do
      let(:response_body) { { server: { status: "migrating" } }.to_json }

      it "returns 'provisioning'" do
        VCR.turned_off { expect(provider.server_status("12345")).to eq("provisioning") }
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

  describe "#server_progress" do
    it "returns the progress of the create_server action" do
      stub_request(:get, "https://api.hetzner.cloud/v1/servers/12345/actions")
        .with(headers: { "Authorization" => "Bearer #{api_token}" })
        .to_return(status: 200, body: {
          actions: [
            { command: "start_server", progress: 100 },
            { command: "create_server", progress: 42 }
          ]
        }.to_json)

      VCR.turned_off { expect(provider.server_progress("12345")).to eq(42) }
    end

    it "returns nil when there is no create_server action" do
      stub_request(:get, "https://api.hetzner.cloud/v1/servers/12345/actions")
        .to_return(status: 200, body: { actions: [ { command: "start_server", progress: 100 } ] }.to_json)

      VCR.turned_off { expect(provider.server_progress("12345")).to be_nil }
    end

    it "returns nil when the API call fails" do
      stub_request(:get, "https://api.hetzner.cloud/v1/servers/12345/actions")
        .to_return(status: 500, body: "oops")

      VCR.turned_off { expect(provider.server_progress("12345")).to be_nil }
    end
  end

  describe "#list_servers" do
    it "follows pagination and maps each server" do
      stub_request(:get, "https://api.hetzner.cloud/v1/servers?page=1&per_page=50")
        .with(headers: { "Authorization" => "Bearer #{api_token}" })
        .to_return(status: 200, body: {
          servers: [ { id: 1, name: "serveme-1", created: "2026-08-03T19:11:25+00:00" } ],
          meta: { pagination: { last_page: 2 } }
        }.to_json)
      stub_request(:get, "https://api.hetzner.cloud/v1/servers?page=2&per_page=50")
        .to_return(status: 200, body: {
          servers: [ { id: 2, name: "serveme-2", created: nil } ],
          meta: { pagination: { last_page: 2 } }
        }.to_json)

      VCR.turned_off do
        expect(provider.list_servers).to eq([
          { provider_id: "1", label: "serveme-1", created_at: Time.parse("2026-08-03T19:11:25+00:00") },
          { provider_id: "2", label: "serveme-2", created_at: nil }
        ])
      end
    end

    it "returns what it collected so far when a page fails" do
      stub_request(:get, "https://api.hetzner.cloud/v1/servers?page=1&per_page=50")
        .to_return(status: 200, body: {
          servers: [ { id: 1, name: "serveme-1" } ],
          meta: { pagination: { last_page: 3 } }
        }.to_json)
      stub_request(:get, "https://api.hetzner.cloud/v1/servers?page=2&per_page=50")
        .to_return(status: 503, body: "unavailable")

      VCR.turned_off do
        expect(provider.list_servers.map { |s| s[:provider_id] }).to eq([ "1" ])
      end
    end
  end

  describe "#create_bare_server" do
    before do
      allow(provider).to receive(:sleep)
      stub_request(:post, "https://api.hetzner.cloud/v1/servers")
        .to_return(status: 201, body: { server: { id: 777 } }.to_json)
    end

    it "creates the VM, polls until it is running with an IP and returns both" do
      stub_request(:get, "https://api.hetzner.cloud/v1/servers/777")
        .to_return(
          { status: 200, body: { server: { status: "initializing", public_net: { ipv4: { ip: nil } } } }.to_json },
          { status: 200, body: { server: { status: "running", public_net: { ipv4: { ip: "5.6.7.8" } } } }.to_json }
        )

      VCR.turned_off do
        expect(provider.create_bare_server(name: "bare", location: "ash")).to eq([ "777", "5.6.7.8" ])

        expect(WebMock).to have_requested(:post, "https://api.hetzner.cloud/v1/servers")
          .with { |req|
            body = JSON.parse(req.body)
            body == {
              "name" => "bare", "server_type" => "cpx21", "image" => "ubuntu-24.04",
              "location" => "ash", "ssh_keys" => [ "serveme-cloud" ]
            }
          }
        expect(WebMock).to have_requested(:get, "https://api.hetzner.cloud/v1/servers/777").twice
      end
    end

    it "passes image and user_data through when given" do
      stub_request(:get, "https://api.hetzner.cloud/v1/servers/777")
        .to_return(status: 200, body: { server: { status: "running", public_net: { ipv4: { ip: "5.6.7.8" } } } }.to_json)

      VCR.turned_off do
        provider.create_bare_server(name: "bare", location: "hel1", image: "docker-ce", user_data: "#cloud-config")

        expect(WebMock).to have_requested(:post, "https://api.hetzner.cloud/v1/servers")
          .with { |req| JSON.parse(req.body).values_at("image", "user_data", "server_type") == [ "docker-ce", "#cloud-config", "cpx22" ] }
      end
    end

    it "raises when the VM never gets an IP" do
      stub_request(:get, "https://api.hetzner.cloud/v1/servers/777")
        .to_return(status: 200, body: { server: { status: "initializing", public_net: { ipv4: { ip: nil } } } }.to_json)

      VCR.turned_off do
        expect { provider.create_bare_server(name: "bare", location: "fsn1") }
          .to raise_error("Hetzner VM never became running")
        expect(WebMock).to have_requested(:get, "https://api.hetzner.cloud/v1/servers/777").times(60)
      end
    end

    it "raises when the VM has an IP but never reaches running" do
      stub_request(:get, "https://api.hetzner.cloud/v1/servers/777")
        .to_return(status: 200, body: { server: { status: "initializing", public_net: { ipv4: { ip: "5.6.7.8" } } } }.to_json)

      VCR.turned_off do
        expect { provider.create_bare_server(name: "bare", location: "fsn1") }
          .to raise_error("Hetzner VM never became running")
        expect(WebMock).to have_requested(:get, "https://api.hetzner.cloud/v1/servers/777").times(60)
      end
    end

    it "raises when the create call fails" do
      stub_request(:post, "https://api.hetzner.cloud/v1/servers")
        .to_return(status: 422, body: { error: { message: "invalid" } }.to_json)

      VCR.turned_off do
        expect { provider.create_bare_server(name: "bare", location: "fsn1") }.to raise_error(/Hetzner API error/)
      end
    end

    it "raises without polling when the API returns no server id" do
      stub_request(:post, "https://api.hetzner.cloud/v1/servers")
        .to_return(status: 201, body: { server: {} }.to_json)

      VCR.turned_off do
        expect { provider.create_bare_server(name: "bare", location: "fsn1") }.to raise_error(/Hetzner API returned no server id/)
        expect(WebMock).not_to have_requested(:get, %r{/servers/})
      end
    end
  end

  describe "#create_snapshot_server" do
    it "creates a docker-ce VM named after the current time with the setup script" do
      allow(provider).to receive(:sleep)
      stub_request(:post, "https://api.hetzner.cloud/v1/servers")
        .to_return(status: 201, body: { server: { id: 888 } }.to_json)
      stub_request(:get, "https://api.hetzner.cloud/v1/servers/888")
        .to_return(status: 200, body: { server: { status: "running", public_net: { ipv4: { ip: "9.9.9.9" } } } }.to_json)

      travel_to(Time.zone.local(2026, 9, 27, 13, 45)) do
        VCR.turned_off do
          expect(provider.create_snapshot_server("nbg1", "#!/bin/bash")).to eq([ "888", "9.9.9.9" ])

          expect(WebMock).to have_requested(:post, "https://api.hetzner.cloud/v1/servers")
            .with { |req|
              JSON.parse(req.body).values_at("name", "image", "location", "user_data") ==
                [ "serveme-snapshot-202609271345", "docker-ce", "nbg1", "#!/bin/bash" ]
            }
        end
      end
    end
  end

  describe "#halt_server" do
    before do
      allow(provider).to receive(:sleep)
      stub_request(:post, "https://api.hetzner.cloud/v1/servers/12345/actions/shutdown")
        .to_return(status: 201, body: {}.to_json)
    end

    it "sends a shutdown and returns once the VM is off" do
      stub_request(:get, "https://api.hetzner.cloud/v1/servers/12345")
        .to_return(
          { status: 200, body: { server: { status: "stopping" } }.to_json },
          { status: 200, body: { server: { status: "off" } }.to_json }
        )

      VCR.turned_off do
        expect { provider.halt_server("12345") }.not_to raise_error
        expect(WebMock).to have_requested(:post, "https://api.hetzner.cloud/v1/servers/12345/actions/shutdown").once
        expect(WebMock).to have_requested(:get, "https://api.hetzner.cloud/v1/servers/12345").twice
      end
    end

    it "raises when the VM never powers off" do
      stub_request(:get, "https://api.hetzner.cloud/v1/servers/12345")
        .to_return(status: 200, body: { server: { status: "running" } }.to_json)

      VCR.turned_off do
        expect { provider.halt_server("12345") }.to raise_error("Hetzner VM did not power off in time")
        expect(WebMock).to have_requested(:get, "https://api.hetzner.cloud/v1/servers/12345").times(30)
      end
    end
  end

  describe "#create_snapshot" do
    it "requests a snapshot image and returns its id" do
      stub_request(:post, "https://api.hetzner.cloud/v1/servers/12345/actions/create_image")
        .with(body: { type: "snapshot", description: "serveme-cloud-20260927" }.to_json)
        .to_return(status: 201, body: { image: { id: 4242 } }.to_json)

      VCR.turned_off { expect(provider.create_snapshot("12345", "serveme-cloud-20260927")).to eq("4242") }
    end

    it "raises on an API error" do
      stub_request(:post, "https://api.hetzner.cloud/v1/servers/12345/actions/create_image")
        .to_return(status: 409, body: { error: { message: "locked" } }.to_json)

      VCR.turned_off do
        expect { provider.create_snapshot("12345", "x") }.to raise_error(/Hetzner snapshot error/)
      end
    end
  end

  describe "#wait_for_snapshot" do
    before do
      allow(provider).to receive(:sleep)
      allow(provider).to receive(:print)
    end

    it "returns once the image is available" do
      stub_request(:get, "https://api.hetzner.cloud/v1/images/4242")
        .to_return(
          { status: 200, body: { image: { status: "creating" } }.to_json },
          { status: 200, body: { image: { status: "available" } }.to_json }
        )

      VCR.turned_off do
        expect { provider.wait_for_snapshot("4242") }.not_to raise_error
        expect(WebMock).to have_requested(:get, "https://api.hetzner.cloud/v1/images/4242").twice
      end
    end

    it "raises when the image never becomes available" do
      stub_request(:get, "https://api.hetzner.cloud/v1/images/4242")
        .to_return(status: 200, body: { image: { status: "creating" } }.to_json)

      VCR.turned_off do
        expect { provider.wait_for_snapshot("4242") }
          .to raise_error("Hetzner snapshot did not become available in time")
        expect(WebMock).to have_requested(:get, "https://api.hetzner.cloud/v1/images/4242").times(180)
      end
    end
  end

  describe "provisioning estimates" do
    it "sums its phases to roughly the advertised provision time" do
      expect(provider.provision_phases.map { |p| p[:key] })
        .to eq(%w[creating_vm booting configuring booting_tf2 starting_tf2])
      expect(provider.provision_phases.sum { |p| p[:seconds] }).to be_within(60).of(4.minutes)
      expect(provider.estimated_provision_time).to eq("about 4 minutes")
    end
  end

  describe "#snapshot_credential_key" do
    it "points at the hetzner image_id credential" do
      expect(provider.snapshot_credential_key).to eq("cloud_servers.hetzner.image_id")
    end
  end

  describe "snapshot housekeeping" do
    let(:images_url) { "https://api.hetzner.cloud/v1/images?page=%d&per_page=50&sort=created:desc&type=snapshot" }

    before do
      stub_request(:get, format(images_url, 1))
        .with(headers: { "Authorization" => "Bearer #{api_token}" })
        .to_return(status: 200, body: {
          images: [
            { id: 3, description: "serveme-cloud-20260903" },
            { id: 99, description: "someone-elses-backup" }
          ],
          meta: { pagination: { last_page: 2 } }
        }.to_json)
      stub_request(:get, format(images_url, 2))
        .to_return(status: 200, body: {
          images: [
            { id: 2, description: "serveme-cloud-20260902" },
            { id: 1, description: "serveme-cloud-20260901" }
          ],
          meta: { pagination: { last_page: 2 } }
        }.to_json)
    end

    describe "#list_snapshots" do
      it "collects serveme snapshots across all pages" do
        VCR.turned_off { expect(provider.list_snapshots.map { |i| i["id"] }).to eq([ 3, 2, 1 ]) }
      end

      it "raises when the API errors" do
        stub_request(:get, format(images_url, 1)).to_return(status: 401, body: { error: { message: "unauthorized" } }.to_json)

        VCR.turned_off { expect { provider.list_snapshots }.to raise_error(/Hetzner API error/) }
      end

      it "treats a response without images as an empty page" do
        stub_request(:get, format(images_url, 1)).to_return(status: 200, body: { meta: { pagination: { last_page: 1 } } }.to_json)

        VCR.turned_off { expect(provider.list_snapshots).to eq([]) }
      end
    end

    describe "#delete_snapshot" do
      it "returns true when the delete succeeds" do
        stub_request(:delete, "https://api.hetzner.cloud/v1/images/3").to_return(status: 204)

        VCR.turned_off { expect(provider.delete_snapshot(3)).to be true }
      end

      it "returns false when the delete fails" do
        stub_request(:delete, "https://api.hetzner.cloud/v1/images/3").to_return(status: 404)

        VCR.turned_off { expect(provider.delete_snapshot("3")).to be false }
      end
    end

    describe "#delete_old_snapshots" do
      it "deletes every serveme snapshot except the kept one and counts successes" do
        stub_request(:delete, "https://api.hetzner.cloud/v1/images/2").to_return(status: 204)
        stub_request(:delete, "https://api.hetzner.cloud/v1/images/1").to_return(status: 500)

        VCR.turned_off do
          expect(provider.delete_old_snapshots("3")).to eq(1)

          expect(WebMock).not_to have_requested(:delete, "https://api.hetzner.cloud/v1/images/3")
          expect(WebMock).not_to have_requested(:delete, "https://api.hetzner.cloud/v1/images/99")
          expect(WebMock).to have_requested(:delete, "https://api.hetzner.cloud/v1/images/2").once
          expect(WebMock).to have_requested(:delete, "https://api.hetzner.cloud/v1/images/1").once
        end
      end
    end
  end
end
