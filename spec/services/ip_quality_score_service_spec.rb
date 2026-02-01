# typed: false
# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

describe IpQualityScoreService do
  let(:api_key) { "test_api_key" }
  let(:ip) { "47.154.67.194" }

  before do
    allow(Rails.application.credentials).to receive(:dig)
      .with(:ipqs, :api_key).and_return(api_key)
  end

  describe ".check" do
    let(:api_response) do
      {
        "success" => true,
        "proxy" => true,
        "connection_type" => "Residential",
        "fraud_score" => 85,
        "ISP" => "Test ISP",
        "country_code" => "US"
      }
    end

    it "makes an API request and creates an IpLookup record" do
      stub_request(:get, "https://www.ipqualityscore.com/api/json/ip/#{api_key}/#{ip}?strictness=1")
        .to_return(status: 200, body: api_response.to_json)

      result = described_class.check(ip)

      expect(result).to be_a(IpLookup)
      expect(result.ip).to eq(ip)
      expect(result.is_proxy).to be true
      expect(result.fraud_score).to eq(85)
      expect(result.connection_type).to eq("Residential")
      expect(result.isp).to eq("Test ISP")
      expect(result.country_code).to eq("US")
      expect(result.raw_response).to eq(api_response)
    end

    it "detects residential proxy when proxy is true and connection_type is Residential" do
      stub_request(:get, "https://www.ipqualityscore.com/api/json/ip/#{api_key}/#{ip}?strictness=1")
        .to_return(status: 200, body: api_response.to_json)

      result = described_class.check(ip)

      expect(result.is_residential_proxy).to be true
    end

    it "detects VPN" do
      vpn_response = api_response.merge("vpn" => true, "proxy" => false, "connection_type" => "Cable/DSL")

      stub_request(:get, "https://www.ipqualityscore.com/api/json/ip/#{api_key}/#{ip}?strictness=1")
        .to_return(status: 200, body: vpn_response.to_json)

      result = described_class.check(ip)

      expect(result.is_residential_proxy).to be true
    end

    it "detects Tor" do
      tor_response = api_response.merge("tor" => true, "proxy" => false, "connection_type" => "Cable/DSL")

      stub_request(:get, "https://www.ipqualityscore.com/api/json/ip/#{api_key}/#{ip}?strictness=1")
        .to_return(status: 200, body: tor_response.to_json)

      result = described_class.check(ip)

      expect(result.is_residential_proxy).to be true
    end

    it "detects active VPN" do
      active_vpn_response = api_response.merge("active_vpn" => true, "proxy" => false, "connection_type" => "Cable/DSL")

      stub_request(:get, "https://www.ipqualityscore.com/api/json/ip/#{api_key}/#{ip}?strictness=1")
        .to_return(status: 200, body: active_vpn_response.to_json)

      result = described_class.check(ip)

      expect(result.is_residential_proxy).to be true
    end

    it "detects active Tor" do
      active_tor_response = api_response.merge("active_tor" => true, "proxy" => false, "connection_type" => "Cable/DSL")

      stub_request(:get, "https://www.ipqualityscore.com/api/json/ip/#{api_key}/#{ip}?strictness=1")
        .to_return(status: 200, body: active_tor_response.to_json)

      result = described_class.check(ip)

      expect(result.is_residential_proxy).to be true
    end

    it "does not flag as residential proxy for normal IPs" do
      normal_response = api_response.merge("fraud_score" => 10, "proxy" => false, "connection_type" => "Cable/DSL")

      stub_request(:get, "https://www.ipqualityscore.com/api/json/ip/#{api_key}/#{ip}?strictness=1")
        .to_return(status: 200, body: normal_response.to_json)

      result = described_class.check(ip)

      expect(result.is_residential_proxy).to be false
    end

    context "when API returns an error status" do
      it "raises ApiError on HTTP error" do
        stub_request(:get, "https://www.ipqualityscore.com/api/json/ip/#{api_key}/#{ip}?strictness=1")
          .to_return(status: 500, body: "Internal Server Error")

        expect { described_class.check(ip) }.to raise_error(IpQualityScoreService::ApiError, /HTTP 500/)
      end

      it "raises ApiError when success is false" do
        error_response = { "success" => false, "message" => "Invalid API key" }

        stub_request(:get, "https://www.ipqualityscore.com/api/json/ip/#{api_key}/#{ip}?strictness=1")
          .to_return(status: 200, body: error_response.to_json)

        expect { described_class.check(ip) }.to raise_error(IpQualityScoreService::ApiError, /Invalid API key/)
      end
    end
  end
end
