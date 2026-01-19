# typed: false
# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

RSpec.describe DiscordReservationNotifier do
  let(:user) { create(:user) }
  let(:server) { create(:server) }
  let(:reservation) do
    create(:reservation,
           user: user,
           server: server,
           starts_at: Time.current,
           ends_at: 2.hours.from_now,
           discord_channel_id: "123456789",
           discord_message_id: "987654321")
  end
  let(:notifier) { described_class.new(reservation) }

  before do
    allow(Rails.application.credentials).to receive(:dig)
      .with(:discord, :eu_token).and_return("test_token")
  end

  describe "#tracking?" do
    it "returns true when discord_channel_id and discord_message_id are present" do
      expect(notifier.tracking?).to be true
    end

    it "returns false when discord_channel_id is missing" do
      reservation.update_columns(discord_channel_id: nil)
      expect(notifier.tracking?).to be false
    end

    it "returns false when discord_message_id is missing" do
      reservation.update_columns(discord_message_id: nil)
      expect(notifier.tracking?).to be false
    end
  end

  describe "#update" do
    before do
      stub_request(:patch, %r{discord.com/api/v10/channels/123456789/messages/987654321})
        .to_return(status: 200, body: "{}".to_json)
    end

    it "calls DiscordApiClient.update_message" do
      expect(DiscordApiClient).to receive(:update_message).with(
        channel_id: "123456789",
        message_id: "987654321",
        embed: hash_including(:title, :color, :fields),
        components: anything
      )
      notifier.update
    end

    it "does nothing when not tracking" do
      reservation.update_columns(discord_channel_id: nil)
      expect(DiscordApiClient).not_to receive(:update_message)
      notifier.update
    end

    context "when reservation has ended" do
      before do
        reservation.update_columns(ended: true)
      end

      it "clears discord fields after update" do
        notifier.update
        reservation.reload
        expect(reservation.discord_channel_id).to be_nil
        expect(reservation.discord_message_id).to be_nil
      end

      it "includes Logs & Demos button" do
        expect(DiscordApiClient).to receive(:update_message).with(
          hash_including(
            components: [ hash_including(
              components: [ hash_including(label: "Logs & Demos") ]
            ) ]
          )
        )
        notifier.update
      end
    end

    context "when reservation is active" do
      it "includes End, Extend, and RCON buttons" do
        expect(DiscordApiClient).to receive(:update_message).with(
          hash_including(
            components: [ hash_including(
              components: array_including(
                hash_including(label: "End"),
                hash_including(label: "Extend"),
                hash_including(label: "RCON")
              )
            ) ]
          )
        )
        notifier.update
      end
    end
  end

  describe "embed content" do
    before do
      allow(DiscordApiClient).to receive(:update_message)
    end

    it "shows 'starting' status when not provisioned" do
      reservation.update_columns(provisioned: false)
      notifier.update

      expect(DiscordApiClient).to have_received(:update_message).with(
        hash_including(
          embed: hash_including(
            fields: array_including(
              hash_including(name: "Status", value: match(/Starting/))
            )
          )
        )
      )
    end

    it "shows 'ready' status when provisioned" do
      reservation.update_columns(provisioned: true)
      notifier.update

      expect(DiscordApiClient).to have_received(:update_message).with(
        hash_including(
          embed: hash_including(
            fields: array_including(
              hash_including(name: "Status", value: ":green_circle: Server Ready")
            )
          )
        )
      )
    end

    it "uses current map from server statistics when available" do
      # Disable the callback to prevent extra Discord updates
      allow(DiscordReservationUpdateWorker).to receive(:perform_async)

      create(:server_statistic,
             reservation: reservation,
             server: server,
             map_name: "cp_process_f12",
             number_of_players: 8)

      notifier.update

      expect(DiscordApiClient).to have_received(:update_message).with(
        hash_including(
          embed: hash_including(
            fields: array_including(
              hash_including(name: "Map", value: "cp_process_f12")
            )
          )
        )
      ).once
    end

    it "uses player count from server statistics when available" do
      # Disable the callback to prevent extra Discord updates
      allow(DiscordReservationUpdateWorker).to receive(:perform_async)

      create(:server_statistic,
             reservation: reservation,
             server: server,
             map_name: "cp_badlands",
             number_of_players: 12)

      notifier.update

      expect(DiscordApiClient).to have_received(:update_message).with(
        hash_including(
          embed: hash_including(
            fields: array_including(
              hash_including(name: "Players", value: "12/24")
            )
          )
        )
      ).once
    end
  end

  describe "rate limit handling" do
    it "re-raises RateLimitError for Sidekiq retry" do
      allow(DiscordApiClient).to receive(:update_message)
        .and_raise(DiscordApiClient::RateLimitError.new(5.0))

      expect { notifier.update }.to raise_error(DiscordApiClient::RateLimitError)
    end

    it "swallows other API errors" do
      allow(DiscordApiClient).to receive(:update_message)
        .and_raise(DiscordApiClient::ApiError.new("Test error"))

      expect { notifier.update }.not_to raise_error
    end
  end
end
