# typed: false

require "spec_helper"
require "webmock/rspec"

RSpec.describe OzfortressApi do
  describe ".steam_id_for_discord" do
    let(:discord_uid) { "123456789012345678" }
    let(:api_key) { "test_api_key" }

    before do
      allow(Rails.application.credentials).to receive(:dig).and_call_original
      allow(Rails.application.credentials).to receive(:dig)
        .with(:ozfortress, :api_key)
        .and_return(api_key)
    end

    context "when API returns a valid user" do
      let(:response_body) do
        {
          user: {
            id: 1,
            name: "TestPlayer",
            steam_64: 76561198012345678,
            steam_64_str: "76561198012345678",
            discord_id: 123456789012345678
          }
        }.to_json
      end

      it "returns the steam_64_str" do
        VCR.use_cassette("ozfortress_api/valid_user") do
          stub_request(:get, "https://ozfortress.com/api/v1/users/discord_id/#{discord_uid}")
            .with(headers: { "X-API-Key" => api_key })
            .to_return(status: 200, body: response_body)

          expect(described_class.steam_id_for_discord(discord_uid)).to eq("76561198012345678")
        end
      end
    end

    context "when API returns 404" do
      it "returns nil" do
        VCR.use_cassette("ozfortress_api/not_found") do
          stub_request(:get, "https://ozfortress.com/api/v1/users/discord_id/#{discord_uid}")
            .with(headers: { "X-API-Key" => api_key })
            .to_return(status: 404, body: { error: "Not found" }.to_json)

          expect(described_class.steam_id_for_discord(discord_uid)).to be_nil
        end
      end
    end

    context "when API returns 403 (Discord integration disabled)" do
      it "returns nil" do
        VCR.use_cassette("ozfortress_api/forbidden") do
          stub_request(:get, "https://ozfortress.com/api/v1/users/discord_id/#{discord_uid}")
            .with(headers: { "X-API-Key" => api_key })
            .to_return(status: 403, body: { error: "Forbidden" }.to_json)

          expect(described_class.steam_id_for_discord(discord_uid)).to be_nil
        end
      end
    end

    context "when API key is not configured" do
      before do
        allow(Rails.application.credentials).to receive(:dig).and_call_original
        allow(Rails.application.credentials).to receive(:dig)
          .with(:ozfortress, :api_key)
          .and_return(nil)
      end

      it "returns nil without making a request" do
        expect(described_class.steam_id_for_discord(discord_uid)).to be_nil
      end
    end

    context "when API times out" do
      it "returns nil" do
        VCR.use_cassette("ozfortress_api/timeout") do
          stub_request(:get, "https://ozfortress.com/api/v1/users/discord_id/#{discord_uid}")
            .with(headers: { "X-API-Key" => api_key })
            .to_timeout

          expect(described_class.steam_id_for_discord(discord_uid)).to be_nil
        end
      end
    end

    context "when API returns invalid JSON" do
      it "returns nil" do
        VCR.use_cassette("ozfortress_api/invalid_json") do
          stub_request(:get, "https://ozfortress.com/api/v1/users/discord_id/#{discord_uid}")
            .with(headers: { "X-API-Key" => api_key })
            .to_return(status: 200, body: "not json")

          expect(described_class.steam_id_for_discord(discord_uid)).to be_nil
        end
      end
    end
  end
end
