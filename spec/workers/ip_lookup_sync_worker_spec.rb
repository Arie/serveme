# typed: false
# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

describe IpLookupSyncWorker do
  let(:ip_lookup) do
    instance_double(
      IpLookup,
      id: 1,
      ip: "1.2.3.4",
      is_proxy: true,
      is_residential_proxy: true,
      fraud_score: 100,
      connection_type: "Corporate",
      isp: "Test ISP",
      country_code: "US",
      raw_response: { "test" => "data" }
    )
  end

  around do |example|
    VCR.turned_off do
      WebMock.allow_net_connect!
      example.run
      WebMock.disable_net_connect!
    end
  end

  describe "#perform" do
    context "in non-production environment" do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
      end

      it "returns early without syncing" do
        expect(IpLookup).not_to receive(:find_by)
        described_class.new.perform(1)
      end
    end

    context "in production environment" do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
        allow(IpLookup).to receive(:find_by).with(id: 1).and_return(ip_lookup)
      end

      it "returns early when ip_lookup not found" do
        allow(IpLookup).to receive(:find_by).with(id: 999).and_return(nil)
        expect(Faraday).not_to receive(:new)
        described_class.new.perform(999)
      end

      context "when on EU region" do
        before do
          stub_const("SITE_HOST", "serveme.tf")
        end

        it "syncs to NA, SEA, and AU but not EU" do
          allow(Rails.application.credentials).to receive(:dig).and_return("test-api-key")

          %w[na.serveme.tf sea.serveme.tf au.serveme.tf].each do |host|
            stub_request(:post, "https://direct.#{host}/api/ip_lookups")
              .with(
                headers: { "Authorization" => "Bearer test-api-key" },
                body: hash_including("ip_lookup" => hash_including("ip" => "1.2.3.4"))
              )
              .to_return(status: 201)
          end

          described_class.new.perform(1)

          expect(WebMock).to have_requested(:post, "https://direct.na.serveme.tf/api/ip_lookups")
          expect(WebMock).to have_requested(:post, "https://direct.sea.serveme.tf/api/ip_lookups")
          expect(WebMock).to have_requested(:post, "https://direct.au.serveme.tf/api/ip_lookups")
          expect(WebMock).not_to have_requested(:post, "https://direct.serveme.tf/api/ip_lookups")
        end

        it "skips region when credentials are missing" do
          allow(Rails.application.credentials).to receive(:dig).with(:serveme, :na).and_return("na-key")
          allow(Rails.application.credentials).to receive(:dig).with(:serveme, :sea).and_return(nil)
          allow(Rails.application.credentials).to receive(:dig).with(:serveme, :au).and_return("au-key")

          stub_request(:post, "https://direct.na.serveme.tf/api/ip_lookups").to_return(status: 201)
          stub_request(:post, "https://direct.au.serveme.tf/api/ip_lookups").to_return(status: 201)

          described_class.new.perform(1)

          expect(WebMock).to have_requested(:post, "https://direct.na.serveme.tf/api/ip_lookups")
          expect(WebMock).not_to have_requested(:post, "https://direct.sea.serveme.tf/api/ip_lookups")
          expect(WebMock).to have_requested(:post, "https://direct.au.serveme.tf/api/ip_lookups")
        end
      end

      context "when on NA region" do
        before do
          stub_const("SITE_HOST", "na.serveme.tf")
        end

        it "syncs to EU, SEA, and AU but not NA" do
          allow(Rails.application.credentials).to receive(:dig).and_return("test-api-key")

          stub_request(:post, "https://direct.serveme.tf/api/ip_lookups").to_return(status: 201)
          stub_request(:post, "https://direct.sea.serveme.tf/api/ip_lookups").to_return(status: 201)
          stub_request(:post, "https://direct.au.serveme.tf/api/ip_lookups").to_return(status: 201)

          described_class.new.perform(1)

          expect(WebMock).to have_requested(:post, "https://direct.serveme.tf/api/ip_lookups")
          expect(WebMock).to have_requested(:post, "https://direct.sea.serveme.tf/api/ip_lookups")
          expect(WebMock).to have_requested(:post, "https://direct.au.serveme.tf/api/ip_lookups")
          expect(WebMock).not_to have_requested(:post, "https://direct.na.serveme.tf/api/ip_lookups")
        end
      end

      context "error handling" do
        before do
          stub_const("SITE_HOST", "serveme.tf")
          allow(Rails.application.credentials).to receive(:dig).and_return("test-api-key")
        end

        it "logs warning on HTTP error response" do
          stub_request(:post, "https://direct.na.serveme.tf/api/ip_lookups").to_return(status: 500)
          stub_request(:post, "https://direct.sea.serveme.tf/api/ip_lookups").to_return(status: 201)
          stub_request(:post, "https://direct.au.serveme.tf/api/ip_lookups").to_return(status: 201)

          expect(Rails.logger).to receive(:warn).with(/Failed to sync to na: 500/)

          described_class.new.perform(1)
        end

        it "logs warning on connection error and continues to other regions" do
          stub_request(:post, "https://direct.na.serveme.tf/api/ip_lookups").to_raise(Faraday::ConnectionFailed.new("Connection refused"))
          stub_request(:post, "https://direct.sea.serveme.tf/api/ip_lookups").to_return(status: 201)
          stub_request(:post, "https://direct.au.serveme.tf/api/ip_lookups").to_return(status: 201)

          expect(Rails.logger).to receive(:warn).with(/Error syncing to na/)

          described_class.new.perform(1)

          expect(WebMock).to have_requested(:post, "https://direct.sea.serveme.tf/api/ip_lookups")
          expect(WebMock).to have_requested(:post, "https://direct.au.serveme.tf/api/ip_lookups")
        end

        it "logs warning on timeout and continues" do
          stub_request(:post, "https://direct.na.serveme.tf/api/ip_lookups").to_raise(Faraday::TimeoutError.new("Timed out"))
          stub_request(:post, "https://direct.sea.serveme.tf/api/ip_lookups").to_return(status: 201)
          stub_request(:post, "https://direct.au.serveme.tf/api/ip_lookups").to_return(status: 201)

          expect(Rails.logger).to receive(:warn).with(/Error syncing to na/)

          described_class.new.perform(1)
        end
      end
    end
  end
end
