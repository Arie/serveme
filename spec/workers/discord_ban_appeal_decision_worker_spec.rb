# typed: false
# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

describe DiscordBanAppealDecisionWorker do
  let(:user) { create(:user, uid: "76561198012345678", nickname: "BannedPlayer", discord_uid: "111222333") }
  let(:thread_id) { "999888777" }
  let(:admin_message_id) { "666555444" }
  let(:admin_discord_uid) { "222333444" }
  let(:interaction_token) { "test_interaction_token" }

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
    allow(Rails.application.credentials).to receive(:dig).with(:discord, :appeals_admin_channel_id).and_return("admin_channel_456")

    # Set up open appeal in Redis
    Sidekiq.redis do |redis|
      redis.set("ban_appeal_open:76561198012345678", "#{thread_id}:#{admin_message_id}", ex: 604800)
    end
  end

  describe "sidekiq options" do
    it "uses the discord queue" do
      expect(described_class.sidekiq_options["queue"].to_s).to eq("discord")
    end
  end

  describe "#perform" do
    context "when approving" do
      it "archives thread, DMs user, updates admin message, and clears Redis" do
        # Post message in thread
        stub_request(:post, "https://discord.com/api/v10/channels/#{thread_id}/messages")
          .to_return(status: 200, body: { id: "msg_123" }.to_json)

        # Archive thread
        stub_request(:patch, "https://discord.com/api/v10/channels/#{thread_id}")
          .with(body: hash_including("archived" => true, "locked" => true))
          .to_return(status: 200, body: { id: thread_id }.to_json)

        # Create DM channel
        stub_request(:post, "https://discord.com/api/v10/users/@me/channels")
          .with(body: { recipient_id: "111222333" }.to_json)
          .to_return(status: 200, body: { id: "dm_channel_123" }.to_json)

        # Send DM
        stub_request(:post, "https://discord.com/api/v10/channels/dm_channel_123/messages")
          .to_return(status: 200, body: { id: "dm_msg_123" }.to_json)

        # Fetch existing admin message to preserve enrichment data
        stub_request(:get, %r{discord.com/api/v10/channels/.*/messages/#{admin_message_id}})
          .to_return(status: 200, body: {
            id: admin_message_id,
            embeds: [ { title: "Ban Appeal - BannedPlayer", color: 0xFF0000, fields: [ { name: "Ban Reason", value: "cheating" } ] } ]
          }.to_json)

        # Update admin enrichment message (disable buttons, change color)
        stub_request(:patch, %r{discord.com/api/v10/channels/.*/messages/#{admin_message_id}})
          .to_return(status: 200, body: "{}".to_json)

        # Update interaction response
        stub_request(:patch, "https://discord.com/api/v10/webhooks/client_123/#{interaction_token}/messages/@original")
          .to_return(status: 200, body: "{}".to_json)

        described_class.new.perform(user.id, thread_id, admin_message_id, "approved", admin_discord_uid, interaction_token)

        expect(WebMock).to have_requested(:post, "https://discord.com/api/v10/channels/#{thread_id}/messages")
        expect(WebMock).to have_requested(:patch, "https://discord.com/api/v10/channels/#{thread_id}")
        expect(WebMock).to have_requested(:post, "https://discord.com/api/v10/users/@me/channels")

        Sidekiq.redis do |redis|
          expect(redis.get("ban_appeal_open:76561198012345678")).to be_nil
        end
      end
    end

    context "when denying" do
      it "archives thread, DMs user, and keeps cooldown" do
        stub_request(:post, "https://discord.com/api/v10/channels/#{thread_id}/messages")
          .to_return(status: 200, body: { id: "msg_123" }.to_json)

        stub_request(:patch, "https://discord.com/api/v10/channels/#{thread_id}")
          .to_return(status: 200, body: { id: thread_id }.to_json)

        stub_request(:post, "https://discord.com/api/v10/users/@me/channels")
          .to_return(status: 200, body: { id: "dm_channel_123" }.to_json)

        stub_request(:post, "https://discord.com/api/v10/channels/dm_channel_123/messages")
          .to_return(status: 200, body: { id: "dm_msg_123" }.to_json)

        stub_request(:get, %r{discord.com/api/v10/channels/.*/messages/#{admin_message_id}})
          .to_return(status: 200, body: {
            id: admin_message_id,
            embeds: [ { title: "Ban Appeal - BannedPlayer", color: 0xFF0000, fields: [] } ]
          }.to_json)

        stub_request(:patch, %r{discord.com/api/v10/channels/.*/messages/#{admin_message_id}})
          .to_return(status: 200, body: "{}".to_json)

        stub_request(:patch, "https://discord.com/api/v10/webhooks/client_123/#{interaction_token}/messages/@original")
          .to_return(status: 200, body: "{}".to_json)

        # Set cooldown before denial
        Sidekiq.redis do |redis|
          redis.set("ban_appeal_cooldown:76561198012345678", "1", ex: 86400)
        end

        described_class.new.perform(user.id, thread_id, admin_message_id, "denied", admin_discord_uid, interaction_token)

        expect(WebMock).to have_requested(:post, "https://discord.com/api/v10/channels/#{thread_id}/messages")

        Sidekiq.redis do |redis|
          expect(redis.get("ban_appeal_open:76561198012345678")).to be_nil
          expect(redis.get("ban_appeal_cooldown:76561198012345678")).to be_present
        end
      end
    end

    context "when DM fails" do
      it "continues without raising and notes in interaction response" do
        stub_request(:post, "https://discord.com/api/v10/channels/#{thread_id}/messages")
          .to_return(status: 200, body: { id: "msg_123" }.to_json)

        stub_request(:patch, "https://discord.com/api/v10/channels/#{thread_id}")
          .to_return(status: 200, body: { id: thread_id }.to_json)

        # DM channel creation fails (user has DMs disabled)
        stub_request(:post, "https://discord.com/api/v10/users/@me/channels")
          .to_return(status: 403, body: { message: "Cannot send messages to this user" }.to_json)

        stub_request(:get, %r{discord.com/api/v10/channels/.*/messages/#{admin_message_id}})
          .to_return(status: 200, body: {
            id: admin_message_id,
            embeds: [ { title: "Ban Appeal - BannedPlayer", color: 0xFF0000, fields: [] } ]
          }.to_json)

        stub_request(:patch, %r{discord.com/api/v10/channels/.*/messages/#{admin_message_id}})
          .to_return(status: 200, body: "{}".to_json)

        stub_request(:patch, "https://discord.com/api/v10/webhooks/client_123/#{interaction_token}/messages/@original")
          .to_return(status: 200, body: "{}".to_json)

        expect {
          described_class.new.perform(user.id, thread_id, admin_message_id, "approved", admin_discord_uid, interaction_token)
        }.not_to raise_error

        # Thread should still be archived
        expect(WebMock).to have_requested(:patch, "https://discord.com/api/v10/channels/#{thread_id}")
      end
    end
  end
end
