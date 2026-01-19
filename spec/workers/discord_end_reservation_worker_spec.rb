# typed: false
# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

RSpec.describe DiscordEndReservationWorker do
  let(:user) { create(:user) }
  let(:server) { create(:server) }
  let(:reservation) do
    create(:reservation,
           user: user,
           server: server,
           starts_at: Time.current,
           ends_at: 2.hours.from_now,
           provisioned: true)
  end
  let(:discord_interaction_token) { "test_interaction_token" }

  before do
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig)
      .with(:discord, :eu_token).and_return("test_token")
    allow(Rails.application.credentials).to receive(:dig)
      .with(:discord, :eu_client_id).and_return("client_123")

    # Stub the reservation ending process
    allow_any_instance_of(Reservation).to receive(:end_reservation)
  end

  describe "#perform" do
    before do
      stub_request(:patch, %r{discord.com/api/v10/webhooks/client_123/#{discord_interaction_token}/messages/@original})
        .to_return(status: 200, body: "{}".to_json)
    end

    it "ends the reservation" do
      expect_any_instance_of(Reservation).to receive(:end_reservation)
      described_class.new.perform(reservation.id, discord_interaction_token)
    end

    it "sets end_instantly to true" do
      described_class.new.perform(reservation.id, discord_interaction_token)
      expect(reservation.reload.end_instantly).to be true
    end

    it "updates the interaction response with success message" do
      expect(DiscordApiClient).to receive(:update_interaction_response).with(
        interaction_token: discord_interaction_token,
        content: ":white_check_mark: Reservation ##{reservation.id} ended"
      )
      described_class.new.perform(reservation.id, discord_interaction_token)
    end

    it "does nothing when reservation not found" do
      expect(DiscordApiClient).not_to receive(:update_interaction_response)
      described_class.new.perform(-1, discord_interaction_token)
    end

    context "when ending fails" do
      before do
        allow_any_instance_of(Reservation).to receive(:end_reservation)
          .and_raise(StandardError.new("Connection timeout"))
      end

      it "updates the interaction response with error message" do
        expect(DiscordApiClient).to receive(:update_interaction_response).with(
          interaction_token: discord_interaction_token,
          content: ":x: Failed to end reservation: Connection timeout"
        )
        described_class.new.perform(reservation.id, discord_interaction_token)
      end
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
