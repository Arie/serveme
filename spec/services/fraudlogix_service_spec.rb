# typed: false
# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

describe FraudlogixService do
  let(:ip) { "47.154.67.194" }
  let(:url) { "https://iplist.fraudlogix.com/v5?ip=#{ip}" }
  let(:clean) do
    { "Proxy" => false, "VPN" => false, "TOR" => false, "DataCenter" => false,
      "RiskScore" => "Low", "ConnectionType" => "Residential", "ISP" => "Test ISP", "CountryCode" => "US" }
  end

  before do
    allow(Rails.application.credentials).to receive(:dig).with(:fraudlogix, :api_key).and_return("key")
  end

  define_method(:stub_fraudlogix) do |status: 200, body: clean.to_json|
    stub_request(:get, url).with(headers: { "x-api-key" => "key" }).to_return(status: status, body: body)
  end

  describe ".check" do
    it "stores a clean lookup" do
      stub_fraudlogix

      result = described_class.check(ip)

      expect(result).to be_persisted
      expect(result).to have_attributes(ip: ip, is_proxy: false, is_residential_proxy: false, fraud_score: 25,
                                        connection_type: "Residential", isp: "Test ISP", country_code: "US")
    end

    %w[Proxy VPN TOR DataCenter].each do |flag|
      it "flags #{flag} as a residential proxy" do
        stub_fraudlogix(body: clean.merge(flag => true).to_json)

        expect(described_class.check(ip).is_residential_proxy).to be true
      end
    end

    { "Medium" => 50, "High" => 75, "Extreme" => 100, nil => 0 }.each do |risk, score|
      it "maps risk score #{risk.inspect} to #{score}" do
        stub_fraudlogix(body: clean.merge("RiskScore" => risk).to_json)

        expect(described_class.check(ip).fraud_score).to eq(score)
      end
    end

    it "raises QuotaExceededError on 429" do
      stub_fraudlogix(status: 429, body: "")

      expect { described_class.check(ip) }.to raise_error(described_class::QuotaExceededError)
    end

    it "raises QuotaExceededError on 403 mentioning the quota" do
      stub_fraudlogix(status: 403, body: "Monthly quota exceeded")

      expect { described_class.check(ip) }.to raise_error(described_class::QuotaExceededError)
    end

    it "raises ApiError on other 403s" do
      stub_fraudlogix(status: 403, body: "Forbidden")

      expect { described_class.check(ip) }.to raise_error(described_class::ApiError)
    end

    it "raises ApiError on server errors" do
      stub_fraudlogix(status: 500, body: "")

      expect { described_class.check(ip) }.to raise_error(described_class::ApiError)
    end

    it "raises QuotaExceededError on a limit error in the JSON body" do
      stub_fraudlogix(body: { "error" => "Daily Limit reached" }.to_json)

      expect { described_class.check(ip) }.to raise_error(described_class::QuotaExceededError)
    end

    it "does not store anything when the request fails" do
      stub_fraudlogix(status: 500, body: "")

      expect { described_class.check(ip) rescue nil }.not_to change(IpLookup, :count)
    end
  end
end
