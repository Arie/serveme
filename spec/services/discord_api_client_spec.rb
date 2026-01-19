# typed: false
# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

RSpec.describe DiscordApiClient do
  describe ".update_message" do
    let(:channel_id) { "123456789" }
    let(:message_id) { "987654321" }
    let(:embed) { { title: "Test", color: 0x00FF00 } }

    before do
      allow(Rails.application.credentials).to receive(:dig)
        .with(:discord, :eu_token).and_return("test_token")
    end

    it "sends a PATCH request to Discord API" do
      stub_request(:patch, "https://discord.com/api/v10/channels/#{channel_id}/messages/#{message_id}")
        .with(
          headers: { "Authorization" => "Bot test_token", "Content-Type" => "application/json" },
          body: { embeds: [ embed ] }.to_json
        )
        .to_return(status: 200, body: "{}".to_json)

      described_class.update_message(channel_id: channel_id, message_id: message_id, embed: embed)
    end

    it "includes components when provided" do
      components = [ { type: 1, components: [] } ]

      stub_request(:patch, "https://discord.com/api/v10/channels/#{channel_id}/messages/#{message_id}")
        .with(body: { embeds: [ embed ], components: components }.to_json)
        .to_return(status: 200, body: "{}".to_json)

      described_class.update_message(
        channel_id: channel_id,
        message_id: message_id,
        embed: embed,
        components: components
      )
    end

    it "returns nil on 404" do
      stub_request(:patch, "https://discord.com/api/v10/channels/#{channel_id}/messages/#{message_id}")
        .to_return(status: 404, body: "Not found")

      result = described_class.update_message(channel_id: channel_id, message_id: message_id, embed: embed)
      expect(result).to be_nil
    end

    it "raises RateLimitError on 429" do
      stub_request(:patch, "https://discord.com/api/v10/channels/#{channel_id}/messages/#{message_id}")
        .to_return(status: 429, headers: { "Retry-After" => "5.0" })

      expect {
        described_class.update_message(channel_id: channel_id, message_id: message_id, embed: embed)
      }.to raise_error(DiscordApiClient::RateLimitError) { |e|
        expect(e.retry_after).to eq(5.0)
      }
    end

    it "raises ApiError on other errors" do
      stub_request(:patch, "https://discord.com/api/v10/channels/#{channel_id}/messages/#{message_id}")
        .to_return(status: 500, body: "Internal error")

      expect {
        described_class.update_message(channel_id: channel_id, message_id: message_id, embed: embed)
      }.to raise_error(DiscordApiClient::ApiError)
    end
  end

  describe ".update_interaction_response" do
    let(:interaction_token) { "test_interaction_token" }
    let(:content) { "Test message" }

    before do
      allow(Rails.application.credentials).to receive(:dig)
        .with(:discord, :eu_token).and_return("test_token")
      allow(Rails.application.credentials).to receive(:dig)
        .with(:discord, :eu_client_id).and_return("client_123")
    end

    it "sends a PATCH request to the webhook endpoint" do
      stub_request(:patch, "https://discord.com/api/v10/webhooks/client_123/#{interaction_token}/messages/@original")
        .with(
          headers: { "Authorization" => "Bot test_token", "Content-Type" => "application/json" },
          body: { content: content }.to_json
        )
        .to_return(status: 200, body: "{}".to_json)

      described_class.update_interaction_response(interaction_token: interaction_token, content: content)
    end
  end
end
