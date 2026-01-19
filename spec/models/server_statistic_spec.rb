# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe ServerStatistic do
  let(:user) { create(:user) }
  let(:server) { create(:server) }
  let(:reservation) do
    create(:reservation,
           user: user,
           server: server,
           starts_at: Time.current,
           ends_at: 2.hours.from_now)
  end

  describe "#notify_discord" do
    context "when reservation has Discord tracking" do
      before do
        reservation.update_columns(
          discord_channel_id: "123456789",
          discord_message_id: "987654321"
        )
      end

      it "enqueues DiscordReservationUpdateWorker" do
        expect(DiscordReservationUpdateWorker).to receive(:perform_async).with(reservation.id)

        create(:server_statistic,
               reservation: reservation,
               server: server,
               map_name: "cp_badlands",
               number_of_players: 6)
      end
    end

    context "when reservation has no Discord tracking" do
      before do
        reservation.update_columns(
          discord_channel_id: nil,
          discord_message_id: nil
        )
      end

      it "does not enqueue DiscordReservationUpdateWorker" do
        expect(DiscordReservationUpdateWorker).not_to receive(:perform_async)

        create(:server_statistic,
               reservation: reservation,
               server: server,
               map_name: "cp_badlands",
               number_of_players: 6)
      end
    end
  end
end
