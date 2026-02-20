# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mcp::Tools::SearchCoPlayersTool do
  describe "class methods" do
    it "has the correct tool name" do
      expect(described_class.tool_name).to eq("search_co_players")
    end

    it "has a description" do
      expect(described_class.description).to be_a(String)
      expect(described_class.description).not_to be_empty
    end

    it "requires league_admin role" do
      expect(described_class.required_role).to eq(:league_admin)
    end

    it "has an input schema with steam_uid property" do
      schema = described_class.input_schema

      expect(schema[:type]).to eq("object")
      expect(schema[:properties]).to have_key(:steam_uid)
      expect(schema[:properties]).to have_key(:min_shared)
      expect(schema[:properties]).to have_key(:days)
      expect(schema[:properties]).to have_key(:limit)
      expect(schema[:required]).to include("steam_uid")
    end
  end

  describe "#execute" do
    let(:admin_user) { create(:user, :admin) }
    let(:tool) { described_class.new(admin_user) }

    let(:target_steam_uid) { "76561198012345678" }
    let(:co_player_steam_uid) { "76561198099999999" }

    # Create 3 reservations where both target and co-player participate
    let!(:shared_reservations) do
      3.times.map do |i|
        reservation = create(:reservation)
        ReservationPlayer.insert!({
          reservation_id: reservation.id,
          steam_uid: target_steam_uid,
          ip: "10.0.0.1",
          name: "TargetPlayer"
        })
        ReservationPlayer.insert!({
          reservation_id: reservation.id,
          steam_uid: co_player_steam_uid,
          ip: "10.0.0.2",
          name: "CoPlayer"
        })
        reservation
      end
    end

    context "with valid steam_uid parameter" do
      it "returns co-players for the target" do
        result = tool.execute(steam_uid: target_steam_uid)

        expect(result[:co_players]).to be_an(Array)
        expect(result[:steam_uid]).to eq(target_steam_uid)
        expect(result[:error]).to be_nil
      end

      it "includes co-player details" do
        result = tool.execute(steam_uid: target_steam_uid)

        co_player = result[:co_players].find { |p| p[:steam_uid] == co_player_steam_uid }
        expect(co_player).to include(
          steam_uid: co_player_steam_uid,
          name: "CoPlayer",
          shared_reservation_count: 3
        )
      end

      it "returns the target reservation count" do
        result = tool.execute(steam_uid: target_steam_uid)

        expect(result[:target_reservation_count]).to eq(3)
      end

      it "includes all_names for co-players" do
        result = tool.execute(steam_uid: target_steam_uid)

        co_player = result[:co_players].find { |p| p[:steam_uid] == co_player_steam_uid }
        expect(co_player[:all_names]).to include("CoPlayer")
      end
    end

    context "with min_shared filtering" do
      let(:occasional_steam_uid) { "76561198011111111" }

      let!(:occasional_reservation) do
        reservation = create(:reservation)
        ReservationPlayer.insert!({
          reservation_id: reservation.id,
          steam_uid: target_steam_uid,
          ip: "10.0.0.1",
          name: "TargetPlayer"
        })
        ReservationPlayer.insert!({
          reservation_id: reservation.id,
          steam_uid: occasional_steam_uid,
          ip: "10.0.0.3",
          name: "OccasionalPlayer"
        })
        reservation
      end

      it "excludes players below min_shared threshold" do
        result = tool.execute(steam_uid: target_steam_uid, min_shared: 3)

        steam_uids = result[:co_players].map { |p| p[:steam_uid] }
        expect(steam_uids).to include(co_player_steam_uid)
        expect(steam_uids).not_to include(occasional_steam_uid)
      end

      it "includes players when min_shared is lowered" do
        result = tool.execute(steam_uid: target_steam_uid, min_shared: 1)

        steam_uids = result[:co_players].map { |p| p[:steam_uid] }
        expect(steam_uids).to include(co_player_steam_uid)
        expect(steam_uids).to include(occasional_steam_uid)
      end
    end

    context "with days filtering" do
      let(:old_co_player_steam_uid) { "76561198022222222" }

      let!(:old_reservation) do
        reservation = create(:reservation)
        reservation.update_columns(starts_at: 400.days.ago, ends_at: 400.days.ago + 2.hours)

        ReservationPlayer.insert!({
          reservation_id: reservation.id,
          steam_uid: target_steam_uid,
          ip: "10.0.0.1",
          name: "TargetPlayer"
        })
        ReservationPlayer.insert!({
          reservation_id: reservation.id,
          steam_uid: old_co_player_steam_uid,
          ip: "10.0.0.4",
          name: "OldCoPlayer"
        })
        reservation
      end

      # Need 3 old reservations to meet min_shared default of 3
      let!(:more_old_reservations) do
        2.times.map do
          reservation = create(:reservation)
          reservation.update_columns(starts_at: 400.days.ago, ends_at: 400.days.ago + 2.hours)

          ReservationPlayer.insert!({
            reservation_id: reservation.id,
            steam_uid: target_steam_uid,
            ip: "10.0.0.1",
            name: "TargetPlayer"
          })
          ReservationPlayer.insert!({
            reservation_id: reservation.id,
            steam_uid: old_co_player_steam_uid,
            ip: "10.0.0.4",
            name: "OldCoPlayer"
          })
          reservation
        end
      end

      it "excludes old reservations by default" do
        result = tool.execute(steam_uid: target_steam_uid)

        steam_uids = result[:co_players].map { |p| p[:steam_uid] }
        expect(steam_uids).to include(co_player_steam_uid)
        expect(steam_uids).not_to include(old_co_player_steam_uid)
      end

      it "includes old reservations with a larger days value" do
        result = tool.execute(steam_uid: target_steam_uid, days: 730, min_shared: 3)

        steam_uids = result[:co_players].map { |p| p[:steam_uid] }
        expect(steam_uids).to include(co_player_steam_uid)
        expect(steam_uids).to include(old_co_player_steam_uid)
      end
    end

    context "with no shared reservations" do
      let(:loner_steam_uid) { "76561198033333333" }

      let!(:loner_reservation) do
        reservation = create(:reservation)
        ReservationPlayer.insert!({
          reservation_id: reservation.id,
          steam_uid: loner_steam_uid,
          ip: "10.0.0.5",
          name: "LonerPlayer"
        })
        reservation
      end

      it "returns an empty co_players list" do
        result = tool.execute(steam_uid: loner_steam_uid)

        expect(result[:co_players]).to eq([])
        expect(result[:co_player_count]).to eq(0)
      end
    end

    context "with missing steam_uid parameter" do
      it "returns error for nil" do
        result = tool.execute({})

        expect(result[:error]).to include("steam_uid is required")
        expect(result[:co_players]).to eq([])
      end

      it "returns error for blank string" do
        result = tool.execute(steam_uid: "")

        expect(result[:error]).to include("steam_uid is required")
        expect(result[:co_players]).to eq([])
      end
    end

    context "with limit parameter" do
      let!(:many_co_players) do
        5.times.map do |i|
          reservations = 3.times.map do
            reservation = create(:reservation)
            ReservationPlayer.insert!({
              reservation_id: reservation.id,
              steam_uid: target_steam_uid,
              ip: "10.0.0.1",
              name: "TargetPlayer"
            })
            ReservationPlayer.insert!({
              reservation_id: reservation.id,
              steam_uid: "7656119800#{i}000000",
              ip: "10.0.#{i}.1",
              name: "BulkPlayer#{i}"
            })
            reservation
          end
        end
      end

      it "respects the limit" do
        result = tool.execute(steam_uid: target_steam_uid, limit: 3)

        expect(result[:co_players].size).to eq(3)
      end
    end
  end
end
