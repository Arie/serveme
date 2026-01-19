# typed: false
# frozen_string_literal: true

require_relative "../spec_helper"

# Test that server statistics queries work correctly for the Discord bot
RSpec.describe "Server statistics queries" do
  let(:user) { create(:user) }
  let(:server) { create(:server) }
  let(:reservation) do
    create(:reservation,
      user: user,
      server: server,
      starts_at: Time.current,
      ends_at: 90.minutes.from_now)
  end

  describe "reservation_players schema" do
    it "reservation_players does NOT have created_at column" do
      # This documents why we cannot filter reservation_players by time
      expect(ReservationPlayer.column_names).not_to include("created_at")
    end
  end

  describe "server statistics queries" do
    it "server_statistics has map_name column" do
      expect(ServerStatistic.column_names).to include("map_name")
    end

    it "server_statistics has number_of_players column" do
      expect(ServerStatistic.column_names).to include("number_of_players")
    end

    it "server_statistics has created_at column" do
      expect(ServerStatistic.column_names).to include("created_at")
    end

    it "can query latest server_statistic for a reservation" do
      stat = create(:server_statistic,
        reservation: reservation,
        map_name: "cp_badlands",
        number_of_players: 6,
        created_at: 1.minute.ago)

      latest = ServerStatistic
        .where(reservation_id: reservation.id)
        .order(created_at: :desc)
        .first

      expect(latest).to eq(stat)
      expect(latest.map_name).to eq("cp_badlands")
      expect(latest.number_of_players).to eq(6)
    end
  end
end
