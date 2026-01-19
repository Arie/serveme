# typed: false
# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

RSpec.describe DiscordReservationUpdateWorker do
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

  before do
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig)
      .with(:discord, :eu_token).and_return("test_token")
  end

  describe "#perform" do
    it "calls notifier.update when reservation exists and is tracking" do
      stub_request(:patch, %r{discord.com/api/v10/channels})
        .to_return(status: 200, body: "{}".to_json)

      expect_any_instance_of(DiscordReservationNotifier).to receive(:update)
      described_class.new.perform(reservation.id)
    end

    it "does nothing when reservation not found" do
      expect_any_instance_of(DiscordReservationNotifier).not_to receive(:update)
      described_class.new.perform(-1)
    end

    it "does nothing when reservation is not tracking Discord" do
      reservation.update_columns(discord_channel_id: nil)
      expect_any_instance_of(DiscordReservationNotifier).not_to receive(:update)
      described_class.new.perform(reservation.id)
    end
  end

  describe "sidekiq options" do
    it "uses the discord queue" do
      expect(described_class.sidekiq_options["queue"]).to eq(:discord)
    end

    it "retries 3 times" do
      expect(described_class.sidekiq_options["retry"]).to eq(3)
    end
  end
end
