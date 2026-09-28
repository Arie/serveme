# typed: false
# frozen_string_literal: true

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

    context "when the API returns 2xx without an instance id" do
      let(:response_body) { { error: "We are currently conducting some software upgrades." }.to_json }

      before do
        allow(Rails.application.credentials).to receive(:dig)
          .with(:cloud_servers, :vultr, :snapshot_id)
          .and_return(nil)
      end

      it "raises a message naming the provider instead of a bare NilClass TypeError" do
        VCR.turned_off do
          expect { provider.create_server(cloud_server) }
            .to raise_error(/Vultr API returned no instance id.*software upgrades/m)
        end
      end
    end

    context "when the plan is not available in the region" do
      before do
        allow(Rails.application.credentials).to receive(:dig)
          .with(:cloud_servers, :vultr, :snapshot_id)
          .and_return(nil)
        stub_request(:post, "https://api.vultr.com/v2/instances")
          .to_return(
            { status: 400, body: { error: "Unable to create instance: plan is not available in the selected region" }.to_json },
            { status: 202, body: response_body }
          )
      end

      it "retries once with the fallback plan" do
        VCR.turned_off do
          expect(provider.create_server(cloud_server)).to eq("cb676a46-66fd-4dfb-b839-443f2e6c0b60")
          expect(WebMock).to have_requested(:post, "https://api.vultr.com/v2/instances")
            .with { |req| JSON.parse(req.body)["plan"] == "vc2-2c-2gb" }.once
          expect(WebMock).to have_requested(:post, "https://api.vultr.com/v2/instances")
            .with { |req| JSON.parse(req.body)["plan"] == "vc2-2c-4gb" }.once
        end
      end
    end

    context "when the API rejects the request for another reason" do
      before do
        allow(Rails.application.credentials).to receive(:dig)
          .with(:cloud_servers, :vultr, :snapshot_id)
          .and_return(nil)
        stub_request(:post, "https://api.vultr.com/v2/instances")
          .to_return(status: 400, body: { error: "Invalid region" }.to_json)
      end

      it "raises without retrying" do
        VCR.turned_off do
          expect { provider.create_server(cloud_server) }.to raise_error(/Vultr API error \(400\)/)
          expect(WebMock).to have_requested(:post, "https://api.vultr.com/v2/instances").once
        end
      end
    end

    context "when the cloud server has no location" do
      let(:cloud_server) { create(:cloud_server, cloud_provider: "vultr", cloud_location: nil) }

      before do
        allow(Rails.application.credentials).to receive(:dig)
          .with(:cloud_servers, :vultr, :snapshot_id)
          .and_return(nil)
      end

      it "uses the default region" do
        VCR.turned_off do
          provider.create_server(cloud_server)
          expect(WebMock).to have_requested(:post, "https://api.vultr.com/v2/instances")
            .with { |req| JSON.parse(req.body)["region"] == "ewr" }
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

    context "when the status is unknown" do
      let(:response_body) { { instance: { status: "resizing", power_status: "running" } }.to_json }

      it "returns 'provisioning'" do
        VCR.turned_off { expect(provider.server_status("abc-123")).to eq("provisioning") }
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

  describe "#find_server_by_label" do
    it "returns the oldest instance carrying the label" do
      stub_request(:get, "https://api.vultr.com/v2/instances?label=serveme-42")
        .with(headers: { "Authorization" => "Bearer #{api_token}" })
        .to_return(status: 200, body: {
          instances: [
            { id: "newer-222", date_created: "2026-08-03T19:13:01+00:00" },
            { id: "oldest-111", date_created: "2026-08-03T19:11:25+00:00" }
          ]
        }.to_json, headers: { "Content-Type" => "application/json" })

      VCR.turned_off { expect(provider.find_server_by_label("serveme-42")).to eq("oldest-111") }
    end

    it "returns nil when nothing carries the label" do
      stub_request(:get, "https://api.vultr.com/v2/instances?label=serveme-99")
        .to_return(status: 200, body: { instances: [] }.to_json, headers: { "Content-Type" => "application/json" })

      VCR.turned_off { expect(provider.find_server_by_label("serveme-99")).to be_nil }
    end

    it "returns nil when the API is unavailable, so provisioning falls through to create" do
      stub_request(:get, "https://api.vultr.com/v2/instances?label=serveme-99")
        .to_return(status: 503, body: "")

      VCR.turned_off { expect(provider.find_server_by_label("serveme-99")).to be_nil }
    end
  end

  # SERVEME-25J / SERVEME-2X2: Vultr 5xx'd on create while still building the
  # VM, so 14 retries billed us for 6 instances on one reservation.
  describe "#find_or_create_server after a failed attempt left a VM behind" do
    let(:cloud_server) { create(:cloud_server, cloud_provider: "vultr", cloud_location: "sto", cloud_reservation_id: 1556649) }

    it "adopts the stranded instance and does not POST another one" do
      stub_request(:get, "https://api.vultr.com/v2/instances?label=#{provider.cloud_server_name(cloud_server)}")
        .to_return(status: 200, body: {
          instances: [ { id: "b98902ec-8c73", date_created: "2026-08-03T19:11:25+00:00" } ]
        }.to_json, headers: { "Content-Type" => "application/json" })

      VCR.turned_off do
        expect(provider.find_or_create_server(cloud_server)).to eq("b98902ec-8c73")
        expect(WebMock).not_to have_requested(:post, "https://api.vultr.com/v2/instances")
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

  describe "#provision_phases and #estimated_provision_time" do
    it "describes a roughly four minute boot" do
      expect(provider.provision_phases.map { |p| p[:key] })
        .to eq(%w[creating_vm booting configuring booting_tf2 starting_tf2])
      expect(provider.provision_phases.sum { |p| p[:seconds] }).to eq(285)
      expect(provider.estimated_provision_time).to eq("about 4 minutes")
    end
  end

  describe "#list_servers" do
    it "follows the pagination cursor and maps each instance" do
      stub_request(:get, "https://api.vultr.com/v2/instances?per_page=100")
        .with(headers: { "Authorization" => "Bearer #{api_token}" })
        .to_return(status: 200, body: {
          instances: [ { id: "aaa", label: "serveme-1", date_created: "2026-09-01T10:00:00+00:00" } ],
          meta: { links: { next: "cursor-2" } }
        }.to_json)
      stub_request(:get, "https://api.vultr.com/v2/instances?per_page=100&cursor=cursor-2")
        .to_return(status: 200, body: {
          instances: [ { id: "bbb", label: "serveme-2", date_created: nil } ],
          meta: { links: { next: "" } }
        }.to_json)

      VCR.turned_off do
        expect(provider.list_servers).to eq([
          { provider_id: "aaa", label: "serveme-1", created_at: Time.parse("2026-09-01T10:00:00+00:00") },
          { provider_id: "bbb", label: "serveme-2", created_at: nil }
        ])
      end
    end

    it "returns what it has collected when a later page fails" do
      stub_request(:get, "https://api.vultr.com/v2/instances?per_page=100")
        .to_return(status: 200, body: {
          instances: [ { id: "aaa", label: "serveme-1" } ],
          meta: { links: { next: "cursor-2" } }
        }.to_json)
      stub_request(:get, "https://api.vultr.com/v2/instances?per_page=100&cursor=cursor-2")
        .to_return(status: 500, body: "")

      VCR.turned_off do
        expect(provider.list_servers).to eq([ { provider_id: "aaa", label: "serveme-1", created_at: nil } ])
      end
    end

    it "handles a response without an instances key" do
      stub_request(:get, "https://api.vultr.com/v2/instances?per_page=100")
        .to_return(status: 200, body: {}.to_json)

      VCR.turned_off { expect(provider.list_servers).to eq([]) }
    end
  end

  describe "#create_bare_server" do
    before do
      allow(provider).to receive(:sleep)
      allow(Rails.application.credentials).to receive(:dig)
        .with(:cloud_servers, :vultr, :ssh_key_id)
        .and_return("ssh-key-id-123")
      stub_request(:post, "https://api.vultr.com/v2/instances")
        .to_return(status: 202, body: { instance: { id: "bare-1" } }.to_json)
    end

    it "creates the VM and polls until it is running with a real IP" do
      stub_request(:get, "https://api.vultr.com/v2/instances/bare-1")
        .to_return(
          { status: 200, body: { instance: { status: "pending", power_status: "stopped", main_ip: "0.0.0.0" } }.to_json },
          { status: 200, body: { instance: { status: "active", power_status: "running", main_ip: "0.0.0.0" } }.to_json },
          { status: 200, body: { instance: { status: "active", power_status: "running", main_ip: "45.76.1.2" } }.to_json }
        )

      VCR.turned_off do
        expect(provider.create_bare_server(name: "bare", location: "ams", user_data: "#!/bin/bash"))
          .to eq([ "bare-1", "45.76.1.2" ])
        expect(WebMock).to have_requested(:get, "https://api.vultr.com/v2/instances/bare-1").times(3)
        expect(WebMock).to have_requested(:post, "https://api.vultr.com/v2/instances")
          .with { |req|
            body = JSON.parse(req.body)
            body["label"] == "bare" && body["region"] == "ams" && body["image_id"] == "docker" &&
              body["plan"] == "vc2-2c-2gb" && body["sshkey_id"] == [ "ssh-key-id-123" ] &&
              Base64.strict_decode64(body["user_data"]) == "#!/bin/bash"
          }
      end
    end

    it "omits user_data and honours a custom image" do
      stub_request(:get, "https://api.vultr.com/v2/instances/bare-1")
        .to_return(status: 200, body: { instance: { status: "active", power_status: "running", main_ip: "45.76.1.2" } }.to_json)

      VCR.turned_off do
        provider.create_bare_server(name: "bare", location: "ams", image: "custom-img")
        expect(WebMock).to have_requested(:post, "https://api.vultr.com/v2/instances")
          .with { |req|
            body = JSON.parse(req.body)
            body["image_id"] == "custom-img" && !body.key?("user_data")
          }
      end
    end

    it "raises when the VM never becomes running" do
      stub_request(:get, "https://api.vultr.com/v2/instances/bare-1")
        .to_return(status: 200, body: { instance: { status: "pending", power_status: "stopped", main_ip: "0.0.0.0" } }.to_json)

      VCR.turned_off do
        expect { provider.create_bare_server(name: "bare", location: "ams") }
          .to raise_error("Vultr VM never became running")
        expect(WebMock).to have_requested(:get, "https://api.vultr.com/v2/instances/bare-1").times(90)
      end
    end

    it "raises when the create call fails" do
      stub_request(:post, "https://api.vultr.com/v2/instances")
        .to_return(status: 400, body: { error: "Invalid plan" }.to_json)

      VCR.turned_off do
        expect { provider.create_bare_server(name: "bare", location: "ams") }.to raise_error(/Vultr API error \(400\)/)
      end
    end
  end

  describe "#create_snapshot_server" do
    it "creates a docker VM named after the current time with the setup script" do
      allow(provider).to receive(:sleep)
      allow(Rails.application.credentials).to receive(:dig)
        .with(:cloud_servers, :vultr, :ssh_key_id)
        .and_return("ssh-key-id-123")
      stub_request(:post, "https://api.vultr.com/v2/instances")
        .to_return(status: 202, body: { instance: { id: "snap-vm" } }.to_json)
      stub_request(:get, "https://api.vultr.com/v2/instances/snap-vm")
        .to_return(status: 200, body: { instance: { status: "active", power_status: "running", main_ip: "9.9.9.9" } }.to_json)

      travel_to(Time.zone.local(2026, 9, 27, 13, 45)) do
        VCR.turned_off do
          expect(provider.create_snapshot_server("fra", "#!/bin/bash")).to eq([ "snap-vm", "9.9.9.9" ])
          expect(WebMock).to have_requested(:post, "https://api.vultr.com/v2/instances")
            .with { |req|
              body = JSON.parse(req.body)
              [ body["label"], body["image_id"], body["region"], Base64.strict_decode64(body["user_data"]) ] ==
                [ "serveme-snapshot-202609271345", "docker", "fra", "#!/bin/bash" ]
            }
        end
      end
    end
  end

  describe "#halt_server" do
    before do
      allow(provider).to receive(:sleep)
      stub_request(:post, "https://api.vultr.com/v2/instances/halt")
        .with(body: { instance_ids: [ "abc-123" ] }.to_json)
        .to_return(status: 204)
    end

    it "halts the VM and returns once it is stopped" do
      stub_request(:get, "https://api.vultr.com/v2/instances/abc-123")
        .to_return(
          { status: 200, body: { instance: { power_status: "running" } }.to_json },
          { status: 200, body: { instance: { power_status: "stopped" } }.to_json }
        )

      VCR.turned_off do
        expect { provider.halt_server("abc-123") }.not_to raise_error
        expect(WebMock).to have_requested(:post, "https://api.vultr.com/v2/instances/halt").once
        expect(WebMock).to have_requested(:get, "https://api.vultr.com/v2/instances/abc-123").twice
      end
    end

    it "raises when the VM never powers off" do
      stub_request(:get, "https://api.vultr.com/v2/instances/abc-123")
        .to_return(status: 200, body: { instance: { power_status: "running" } }.to_json)

      VCR.turned_off do
        expect { provider.halt_server("abc-123") }.to raise_error("Vultr VM did not power off in time")
        expect(WebMock).to have_requested(:get, "https://api.vultr.com/v2/instances/abc-123").times(60)
      end
    end
  end

  describe "#create_snapshot" do
    it "requests a snapshot of the instance and returns its id" do
      stub_request(:post, "https://api.vultr.com/v2/snapshots")
        .with(body: { instance_id: "abc-123", description: "serveme-cloud-20260927" }.to_json)
        .to_return(status: 201, body: { snapshot: { id: "snap-42" } }.to_json)

      VCR.turned_off { expect(provider.create_snapshot("abc-123", "serveme-cloud-20260927")).to eq("snap-42") }
    end

    it "raises with the API error on failure" do
      stub_request(:post, "https://api.vultr.com/v2/snapshots")
        .to_return(status: 400, body: { error: "Instance busy" }.to_json)

      VCR.turned_off do
        expect { provider.create_snapshot("abc-123", "x") }.to raise_error(/Vultr snapshot error \(400\)/)
      end
    end
  end

  describe "#wait_for_snapshot" do
    before do
      allow(provider).to receive(:sleep)
      allow(provider).to receive(:print)
    end

    it "returns once the snapshot is complete" do
      stub_request(:get, "https://api.vultr.com/v2/snapshots/snap-42")
        .to_return(
          { status: 200, body: { snapshot: { status: "pending" } }.to_json },
          { status: 200, body: { snapshot: { status: "complete" } }.to_json }
        )

      VCR.turned_off do
        expect { provider.wait_for_snapshot("snap-42") }.not_to raise_error
        expect(WebMock).to have_requested(:get, "https://api.vultr.com/v2/snapshots/snap-42").twice
        expect(provider).to have_received(:print).with(".").twice
      end
    end

    it "raises when the snapshot never completes" do
      stub_request(:get, "https://api.vultr.com/v2/snapshots/snap-42")
        .to_return(status: 200, body: { snapshot: { status: "pending" } }.to_json)

      VCR.turned_off do
        expect { provider.wait_for_snapshot("snap-42") }.to raise_error("Vultr snapshot did not complete in time")
        expect(WebMock).to have_requested(:get, "https://api.vultr.com/v2/snapshots/snap-42").times(360)
      end
    end
  end

  describe "#snapshot_credential_key" do
    it "points at the vultr snapshot credential" do
      expect(provider.snapshot_credential_key).to eq("cloud_servers.vultr.snapshot_id")
    end
  end
end
