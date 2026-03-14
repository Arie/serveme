# typed: false
# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

describe DiscordBanAppealWorker do
  let(:user) { create(:user, uid: "76561198012345678", nickname: "BannedPlayer", discord_uid: "111222333") }
  let(:discord_user_id) { "111222333" }
  let(:interaction_token) { "test_interaction_token" }
  let(:thread_id) { "999888777" }
  let(:admin_message_id) { "666555444" }

  around do |example|
    VCR.turned_off do
      WebMock.allow_net_connect!
      example.run
      WebMock.disable_net_connect!
    end
  end

  before do
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:discord, :eu_token).and_return("test_token")
    allow(Rails.application.credentials).to receive(:dig).with(:discord, :eu_client_id).and_return("client_123")
    allow(Rails.application.credentials).to receive(:dig).with(:discord, :ban_appeals_channel_id).and_return("appeals_channel_123")
    allow(Rails.application.credentials).to receive(:dig).with(:discord, :appeals_admin_channel_id).and_return("admin_channel_456")
  end

  describe "sidekiq options" do
    it "uses the discord queue" do
      expect(described_class.sidekiq_options["queue"].to_s).to eq("discord")
    end

    it "retries up to 3 times" do
      expect(described_class.sidekiq_options["retry"]).to eq(3)
    end
  end

  describe "#perform" do
    context "when user is banned" do
      let(:enrichment_data) do
        {
          found: true,
          steam_uid: "76561198012345678",
          nickname: "BannedPlayer",
          banned: true,
          ban_reason: "cheating",
          reservation_count: 42,
          first_seen: "2023-01-15",
          last_seen: "2025-12-01",
          regions: [ "eu", "na" ],
          ips: [ "1.2.3.4" ],
          alts: [],
          ip_lookups: []
        }
      end

      before do
        allow_any_instance_of(BanAppealEnrichmentService).to receive(:collect).and_return(enrichment_data)
      end

      it "creates a private thread, posts embeds, and sets Redis keys" do
        # Create private thread
        stub_request(:post, "https://discord.com/api/v10/channels/appeals_channel_123/threads")
          .with(body: hash_including("type" => 12))
          .to_return(status: 200, body: { id: thread_id, name: "Appeal - BannedPlayer" }.to_json)

        # Add user to thread
        stub_request(:put, "https://discord.com/api/v10/channels/#{thread_id}/thread-members/#{discord_user_id}")
          .to_return(status: 204)

        # Post user-facing message in thread
        stub_request(:post, "https://discord.com/api/v10/channels/#{thread_id}/messages")
          .to_return(status: 200, body: { id: "msg_user_123" }.to_json)

        # Post admin enrichment in admin channel
        stub_request(:post, "https://discord.com/api/v10/channels/admin_channel_456/messages")
          .to_return(status: 200, body: { id: admin_message_id }.to_json)

        # Update interaction response
        stub_request(:patch, "https://discord.com/api/v10/webhooks/client_123/#{interaction_token}/messages/@original")
          .to_return(status: 200, body: "{}".to_json)

        described_class.new.perform(user.id, discord_user_id, interaction_token)

        expect(WebMock).to have_requested(:post, "https://discord.com/api/v10/channels/appeals_channel_123/threads")
        expect(WebMock).to have_requested(:put, "https://discord.com/api/v10/channels/#{thread_id}/thread-members/#{discord_user_id}")
        expect(WebMock).to have_requested(:post, "https://discord.com/api/v10/channels/#{thread_id}/messages")
        expect(WebMock).to have_requested(:post, "https://discord.com/api/v10/channels/admin_channel_456/messages")

        Sidekiq.redis do |redis|
          expect(redis.get("ban_appeal_open:76561198012345678")).to be_present
          expect(redis.get("ban_appeal_cooldown:76561198012345678")).to be_present
        end
      end
    end

    context "when user is not found on any region" do
      before do
        allow_any_instance_of(BanAppealEnrichmentService).to receive(:collect).and_return({ found: false })
      end

      it "updates interaction with not-linked message and does not create thread" do
        stub_request(:patch, "https://discord.com/api/v10/webhooks/client_123/#{interaction_token}/messages/@original")
          .to_return(status: 200, body: "{}".to_json)

        described_class.new.perform(user.id, discord_user_id, interaction_token)

        expect(WebMock).to have_requested(:patch, %r{webhooks/client_123/#{interaction_token}})
        expect(WebMock).not_to have_requested(:post, %r{channels/.*/threads})
      end
    end

    context "when user is not banned but appeals anyway" do
      before do
        allow_any_instance_of(BanAppealEnrichmentService).to receive(:collect).and_return({
          found: true,
          steam_uid: "76561198012345678",
          nickname: "NotBannedPlayer",
          banned: false,
          ban_reason: nil,
          reservation_count: 10,
          regions: [ "eu" ],
          ips: [],
          alts: [],
          ip_lookups: []
        })
      end

      it "still creates a thread for admin review" do
        stub_request(:post, "https://discord.com/api/v10/channels/appeals_channel_123/threads")
          .to_return(status: 200, body: { id: thread_id }.to_json)
        stub_request(:put, "https://discord.com/api/v10/channels/#{thread_id}/thread-members/#{discord_user_id}")
          .to_return(status: 204)
        stub_request(:post, "https://discord.com/api/v10/channels/#{thread_id}/messages")
          .to_return(status: 200, body: { id: "msg_123" }.to_json)
        stub_request(:post, "https://discord.com/api/v10/channels/admin_channel_456/messages")
          .to_return(status: 200, body: { id: admin_message_id }.to_json)
        stub_request(:patch, "https://discord.com/api/v10/webhooks/client_123/#{interaction_token}/messages/@original")
          .to_return(status: 200, body: "{}".to_json)

        described_class.new.perform(user.id, discord_user_id, interaction_token)

        expect(WebMock).to have_requested(:post, "https://discord.com/api/v10/channels/appeals_channel_123/threads")
      end
    end
  end
end
