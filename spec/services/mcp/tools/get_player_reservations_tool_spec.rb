# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mcp::Tools::GetPlayerReservationsTool do
  describe "class methods" do
    it "has the correct tool name" do
      expect(described_class.tool_name).to eq("get_player_reservations")
    end

    it "has a description" do
      expect(described_class.description).to be_a(String)
      expect(described_class.description).not_to be_empty
    end

    it "requires public role (available to all)" do
      expect(described_class.required_role).to eq(:public)
    end

    it "has an input schema with steam_uid and discord_uid" do
      schema = described_class.input_schema

      expect(schema[:type]).to eq("object")
      expect(schema[:properties]).to have_key(:steam_uid)
      expect(schema[:properties]).to have_key(:discord_uid)
    end
  end

  describe ".available_to?" do
    it "is available to regular users" do
      user = create(:user)
      expect(described_class.available_to?(user)).to be true
    end
  end

  describe "#execute" do
    let(:user) { create(:user) }
    let(:tool) { described_class.new(user) }

    let(:player) { create(:user, nickname: "TestPlayer", uid: "76561198012345678") }
    let(:server) { create(:server) }
    let(:server2) { create(:server, name: "Server 2") }

    let!(:current_reservation) do
      create(:reservation,
        server: server,
        user: player,
        starts_at: 10.minutes.ago,
        ends_at: 50.minutes.from_now
      )
    end

    let!(:past_reservation) do
      reservation = create(:reservation, server: server2)
      reservation.update_columns(
        user_id: player.id,
        starts_at: 2.hours.ago,
        ends_at: 1.hour.ago
      )
      reservation.reload
    end

    context "with steam_uid parameter" do
      it "returns player reservations" do
        result = tool.execute(steam_uid: player.uid)

        expect(result[:reservations]).to be_an(Array)
        expect(result[:reservations].size).to eq(2)
      end

      it "returns player info" do
        result = tool.execute(steam_uid: player.uid)

        expect(result[:player][:nickname]).to eq("TestPlayer")
        expect(result[:player][:steam_uid]).to eq(player.uid)
      end
    end

    context "with discord_uid parameter" do
      let(:discord_linked_player) do
        create(:user, nickname: "DiscordPlayer", uid: "76561198087654321", discord_uid: "123456789012345678")
      end
      let(:server3) { create(:server, name: "Server 3") }
      let!(:discord_player_reservation) do
        create(:reservation, server: server3, user: discord_linked_player, starts_at: 5.minutes.ago, ends_at: 55.minutes.from_now)
      end

      it "finds player by discord_uid" do
        result = tool.execute(discord_uid: "123456789012345678")

        expect(result[:player][:nickname]).to eq("DiscordPlayer")
        expect(result[:reservations].size).to eq(1)
      end

      it "returns error if discord_uid not linked" do
        result = tool.execute(discord_uid: "999999999999999999")

        expect(result[:error]).to include("not linked")
      end
    end

    context "with invalid parameters" do
      it "returns error if no steam_uid or discord_uid provided" do
        result = tool.execute({})

        expect(result[:error]).to include("steam_uid or discord_uid")
      end

      it "returns error if player not found" do
        result = tool.execute(steam_uid: "76561198099999999")

        expect(result[:error]).to include("not found")
      end
    end

    it "returns non-sensitive reservation data" do
      result = tool.execute(steam_uid: player.uid)

      reservation = result[:reservations].first
      expect(reservation).to include(:id, :server_name, :starts_at, :ends_at, :status, :first_map)

      # Should NOT include sensitive data
      expect(reservation).not_to have_key(:password)
      expect(reservation).not_to have_key(:rcon)
      expect(reservation).not_to have_key(:tv_password)
    end

    context "with limit parameter" do
      it "respects the limit" do
        result = tool.execute(steam_uid: player.uid, limit: 1)

        expect(result[:reservations].size).to eq(1)
      end
    end

    context "with status filter" do
      it "filters by current status" do
        result = tool.execute(steam_uid: player.uid, status: "current")

        expect(result[:reservations].map { |r| r[:id] }).to include(current_reservation.id)
        expect(result[:reservations].map { |r| r[:id] }).not_to include(past_reservation.id)
      end
    end
  end
end
