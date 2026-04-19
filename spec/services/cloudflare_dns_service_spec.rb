# typed: false
# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

describe CloudflareDnsService do
  let(:zone_id) { "fake_zone_id" }
  let(:api_token) { "fake_api_token" }

  before do
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:cloudflare, :dns_zone_id).and_return(zone_id)
    allow(Rails.application.credentials).to receive(:dig).with(:cloudflare, :dns_api_token).and_return(api_token)
  end

  describe "#create_a_record" do
    it "creates an A record via the Cloudflare API" do
      stub = stub_request(:post, "https://api.cloudflare.com/client/v4/zones/#{zone_id}/dns_records")
        .with(
          body: { type: "A", name: "de1.serveme.tf", content: "1.2.3.4", proxied: false, ttl: 1 }.to_json,
          headers: { "Authorization" => "Bearer #{api_token}", "Content-Type" => "application/json" }
        )
        .to_return(status: 200, body: { success: true, result: { id: "record_123" } }.to_json)

      result = described_class.new.create_a_record("de1.serveme.tf", "1.2.3.4")

      expect(stub).to have_been_requested
      expect(result).to eq("record_123")
    end

    it "raises an error when the API returns an error" do
      stub_request(:post, "https://api.cloudflare.com/client/v4/zones/#{zone_id}/dns_records")
        .to_return(status: 400, body: { success: false, errors: [ { message: "Record already exists" } ] }.to_json)

      expect { described_class.new.create_a_record("de1.serveme.tf", "1.2.3.4") }
        .to raise_error(CloudflareDnsService::Error, /Record already exists/)
    end
  end

  describe "#delete_a_record" do
    it "finds and deletes the A record" do
      list_stub = stub_request(:get, "https://api.cloudflare.com/client/v4/zones/#{zone_id}/dns_records?name=de1.serveme.tf&type=A")
        .with(headers: { "Authorization" => "Bearer #{api_token}" })
        .to_return(status: 200, body: { success: true, result: [ { id: "record_123" } ] }.to_json)

      delete_stub = stub_request(:delete, "https://api.cloudflare.com/client/v4/zones/#{zone_id}/dns_records/record_123")
        .with(headers: { "Authorization" => "Bearer #{api_token}" })
        .to_return(status: 200, body: { success: true }.to_json)

      described_class.new.delete_a_record("de1.serveme.tf")

      expect(list_stub).to have_been_requested
      expect(delete_stub).to have_been_requested
    end

    it "does nothing when no record is found" do
      stub_request(:get, "https://api.cloudflare.com/client/v4/zones/#{zone_id}/dns_records?name=de1.serveme.tf&type=A")
        .to_return(status: 200, body: { success: true, result: [] }.to_json)

      expect { described_class.new.delete_a_record("de1.serveme.tf") }.not_to raise_error
    end
  end

  describe "#record_exists?" do
    it "returns true when the record exists" do
      stub_request(:get, "https://api.cloudflare.com/client/v4/zones/#{zone_id}/dns_records?name=de1.serveme.tf&type=A")
        .to_return(status: 200, body: { success: true, result: [ { id: "record_123", content: "1.2.3.4" } ] }.to_json)

      expect(described_class.new.record_exists?("de1.serveme.tf")).to be true
    end

    it "returns false when no record exists" do
      stub_request(:get, "https://api.cloudflare.com/client/v4/zones/#{zone_id}/dns_records?name=de1.serveme.tf&type=A")
        .to_return(status: 200, body: { success: true, result: [] }.to_json)

      expect(described_class.new.record_exists?("de1.serveme.tf")).to be false
    end
  end

  describe "#update_a_record" do
    it "finds and updates the A record with a new IP" do
      list_stub = stub_request(:get, "https://api.cloudflare.com/client/v4/zones/#{zone_id}/dns_records?name=de1.serveme.tf&type=A")
        .to_return(status: 200, body: { success: true, result: [ { id: "record_123" } ] }.to_json)

      update_stub = stub_request(:patch, "https://api.cloudflare.com/client/v4/zones/#{zone_id}/dns_records/record_123")
        .with(
          body: { type: "A", name: "de1.serveme.tf", content: "5.6.7.8", proxied: false, ttl: 1 }.to_json,
          headers: { "Authorization" => "Bearer #{api_token}", "Content-Type" => "application/json" }
        )
        .to_return(status: 200, body: { success: true, result: { id: "record_123" } }.to_json)

      result = described_class.new.update_a_record("de1.serveme.tf", "5.6.7.8")

      expect(list_stub).to have_been_requested
      expect(update_stub).to have_been_requested
      expect(result).to eq("record_123")
    end

    it "raises an error when no record is found to update" do
      stub_request(:get, "https://api.cloudflare.com/client/v4/zones/#{zone_id}/dns_records?name=de1.serveme.tf&type=A")
        .to_return(status: 200, body: { success: true, result: [] }.to_json)

      expect { described_class.new.update_a_record("de1.serveme.tf", "5.6.7.8") }
        .to raise_error(CloudflareDnsService::Error, /No A record found/)
    end
  end
end
