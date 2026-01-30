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
    Rails.cache.clear
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

    it "detects residential proxy when fraud_score is >= 90" do
      high_fraud_response = api_response.merge("fraud_score" => 95, "proxy" => false, "connection_type" => "Cable/DSL")

      stub_request(:get, "https://www.ipqualityscore.com/api/json/ip/#{api_key}/#{ip}?strictness=1")
        .to_return(status: 200, body: high_fraud_response.to_json)

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

    it "increments usage quota" do
      stub_request(:get, "https://www.ipqualityscore.com/api/json/ip/#{api_key}/#{ip}?strictness=1")
        .to_return(status: 200, body: api_response.to_json)

      expect(described_class.current_usage).to eq(0)

      described_class.check(ip)

      expect(described_class.current_usage).to eq(1)
    end

    context "when quota is exceeded" do
      before do
        Rails.cache.write(described_class.quota_key, 1000)
      end

      it "does not make an API request" do
        stub = stub_request(:get, /ipqualityscore/)

        expect { described_class.check(ip) }.to raise_error(IpQualityScoreService::QuotaExceededError)

        expect(stub).not_to have_been_requested
      end
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

  describe ".quota_exceeded?" do
    it "returns false when usage is below quota" do
      expect(described_class.quota_exceeded?).to be false

      Rails.cache.write(described_class.quota_key, 999)
      expect(described_class.quota_exceeded?).to be false
    end

    it "returns true when usage equals quota" do
      Rails.cache.write(described_class.quota_key, 1000)
      expect(described_class.quota_exceeded?).to be true
    end
  end

  describe ".current_usage" do
    it "returns 0 when no usage recorded" do
      expect(described_class.current_usage).to eq(0)
    end

    it "returns the cached usage count" do
      Rails.cache.write(described_class.quota_key, 42)
      expect(described_class.current_usage).to eq(42)
    end
  end

  describe ".quota_key" do
    it "includes the current year and month" do
      travel_to Time.zone.local(2026, 1, 15) do
        expect(described_class.quota_key).to eq("ipqs_monthly_usage:2026-01")
      end
    end

    it "changes month to month" do
      travel_to Time.zone.local(2026, 1, 15) do
        expect(described_class.quota_key).to include("2026-01")
      end

      travel_to Time.zone.local(2026, 2, 15) do
        expect(described_class.quota_key).to include("2026-02")
      end
    end
  end
end
