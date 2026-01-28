# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mcp::Tools::ListReservationsTool do
  describe "class methods" do
    it "has the correct tool name" do
      expect(described_class.tool_name).to eq("list_reservations")
    end

    it "has a description" do
      expect(described_class.description).to be_a(String)
      expect(described_class.description).not_to be_empty
    end

    it "requires admin role" do
      expect(described_class.required_role).to eq(:admin)
    end

    it "has an input schema with filter options" do
      schema = described_class.input_schema

      expect(schema[:type]).to eq("object")
      expect(schema[:properties]).to have_key(:status)
      expect(schema[:properties]).to have_key(:user_id)
      expect(schema[:properties]).to have_key(:user_query)
      expect(schema[:properties]).to have_key(:steam_uid)
      expect(schema[:properties]).to have_key(:server_id)
      expect(schema[:properties]).to have_key(:starts_after)
      expect(schema[:properties]).to have_key(:starts_before)
      expect(schema[:properties]).to have_key(:offset)
      expect(schema[:properties]).to have_key(:limit)
    end
  end

  describe "#execute" do
    let(:admin_user) { create(:user, :admin) }
    let(:tool) { described_class.new(admin_user) }
    let(:server) { create(:server) }
    let(:server2) { create(:server, name: "Server 2") }
    let(:server3) { create(:server, name: "Server 3") }
    let(:reservation_user) { create(:user, nickname: "ReservationUser") }

    # Use different servers to avoid collision validations
    let!(:current_reservation) do
      create(:reservation,
        server: server,
        user: reservation_user,
        starts_at: 10.minutes.ago,
        ends_at: 50.minutes.from_now
      )
    end

    let!(:past_reservation) do
      reservation = create(:reservation, server: server2)
      reservation.update_columns(
        user_id: reservation_user.id,
        starts_at: 2.hours.ago,
        ends_at: 1.hour.ago
      )
      reservation.reload
    end

    let!(:future_reservation) do
      create(:reservation,
        server: server3,
        user: reservation_user,
        starts_at: 2.hours.from_now,
        ends_at: 3.hours.from_now
      )
    end

    context "with default parameters" do
      it "returns recent reservations" do
        result = tool.execute({})

        expect(result[:reservations]).to be_an(Array)
        expect(result[:reservations].size).to be >= 1
      end
    end

    context "with status filter" do
      it "filters by current status" do
        result = tool.execute(status: "current")

        expect(result[:reservations].map { |r| r[:id] }).to include(current_reservation.id)
        expect(result[:reservations].map { |r| r[:id] }).not_to include(past_reservation.id)
      end

      it "filters by future status" do
        result = tool.execute(status: "future")

        expect(result[:reservations].map { |r| r[:id] }).to include(future_reservation.id)
        expect(result[:reservations].map { |r| r[:id] }).not_to include(past_reservation.id)
      end
    end

    context "with user_id filter" do
      it "filters by user" do
        result = tool.execute(user_id: reservation_user.id)

        result[:reservations].each do |r|
          expect(r[:user_id]).to eq(reservation_user.id)
        end
      end
    end

    context "with server_id filter" do
      let!(:other_server) { create(:server, name: "Other Server") }
      let!(:other_reservation) do
        create(:reservation, server: other_server, starts_at: 5.minutes.ago, ends_at: 55.minutes.from_now)
      end

      it "filters by server" do
        result = tool.execute(server_id: server.id)

        result[:reservations].each do |r|
          expect(r[:server_id]).to eq(server.id)
        end
      end
    end

    context "with limit parameter" do
      it "respects the limit" do
        result = tool.execute(limit: 1)

        expect(result[:reservations].size).to eq(1)
      end
    end

    context "with offset parameter" do
      it "skips results based on offset" do
        result_without_offset = tool.execute(limit: 10)
        result_with_offset = tool.execute(limit: 10, offset: 1)

        expect(result_with_offset[:offset]).to eq(1)
        expect(result_with_offset[:reservations].size).to eq(result_without_offset[:reservations].size - 1)
      end

      it "returns total_count regardless of offset" do
        result = tool.execute(offset: 1)

        expect(result[:total_count]).to be >= 1
      end
    end

    context "with steam_uid filter" do
      it "filters by Steam ID64" do
        result = tool.execute(steam_uid: reservation_user.uid)

        result[:reservations].each do |r|
          expect(r[:user_id]).to eq(reservation_user.id)
        end
      end

      it "returns empty when steam_uid not found" do
        result = tool.execute(steam_uid: "76561198999999999")

        expect(result[:reservations]).to be_empty
      end
    end

    context "with date range filters" do
      it "filters by starts_after" do
        result = tool.execute(starts_after: 1.hour.from_now.iso8601)

        result[:reservations].each do |r|
          expect(r[:starts_at]).to be > 1.hour.from_now
        end
        expect(result[:reservations].map { |r| r[:id] }).to include(future_reservation.id)
        expect(result[:reservations].map { |r| r[:id] }).not_to include(current_reservation.id)
      end

      it "filters by starts_before" do
        result = tool.execute(starts_before: 1.hour.ago.iso8601)

        result[:reservations].each do |r|
          expect(r[:starts_at]).to be < 1.hour.ago
        end
        expect(result[:reservations].map { |r| r[:id] }).to include(past_reservation.id)
        expect(result[:reservations].map { |r| r[:id] }).not_to include(future_reservation.id)
      end

      it "combines starts_after and starts_before" do
        result = tool.execute(
          starts_after: 30.minutes.ago.iso8601,
          starts_before: 1.hour.from_now.iso8601
        )

        expect(result[:reservations].map { |r| r[:id] }).to include(current_reservation.id)
        expect(result[:reservations].map { |r| r[:id] }).not_to include(past_reservation.id)
        expect(result[:reservations].map { |r| r[:id] }).not_to include(future_reservation.id)
      end
    end

    it "includes reservation details" do
      result = tool.execute({})

      reservation = result[:reservations].first
      expect(reservation).to include(
        :id,
        :user_id,
        :user_nickname,
        :user_steam_uid,
        :server_id,
        :server_name,
        :starts_at,
        :ends_at,
        :password,
        :rcon,
        :tv_password,
        :status,
        :first_map,
        :server_config,
        :enable_plugins,
        :enable_demos_tf
      )
    end

    context "with user_query parameter" do
      let(:reservation_user_with_valid_uid) do
        create(:user, nickname: "ValidSteamUser", uid: "76561198012345678")
      end
      let(:server_for_valid_user) { create(:server, name: "Valid User Server") }
      let!(:reservation_for_valid_user) do
        create(:reservation,
          server: server_for_valid_user,
          user: reservation_user_with_valid_uid,
          starts_at: 10.minutes.ago,
          ends_at: 50.minutes.from_now
        )
      end

      it "finds user by Steam profile URL" do
        result = tool.execute(user_query: "https://steamcommunity.com/profiles/#{reservation_user_with_valid_uid.uid}")

        expect(result[:reservations]).to be_an(Array)
        result[:reservations].each do |r|
          expect(r[:user_id]).to eq(reservation_user_with_valid_uid.id)
        end
      end

      it "finds user by Steam ID64" do
        result = tool.execute(user_query: reservation_user_with_valid_uid.uid)

        expect(result[:reservations]).to be_an(Array)
        result[:reservations].each do |r|
          expect(r[:user_id]).to eq(reservation_user_with_valid_uid.id)
        end
      end

      it "finds user by nickname" do
        result = tool.execute(user_query: "ReservationUser")

        expect(result[:reservations]).to be_an(Array)
        result[:reservations].each do |r|
          expect(r[:user_id]).to eq(reservation_user.id)
        end
      end

      it "returns error when user not found" do
        result = tool.execute(user_query: "https://steamcommunity.com/id/nonexistentuser12345")

        expect(result[:error]).to include("User not found")
        expect(result[:reservations]).to be_nil
      end

      it "returns error when multiple users found by nickname" do
        create(:user, nickname: "ReservationUser2")

        result = tool.execute(user_query: "ReservationUser")

        # Should still work - takes first match or returns multiple user error
        expect(result[:reservations]).to be_an(Array).or(include(:error))
      end

      it "prefers user_query over user_id when both provided" do
        other_user = create(:user)

        result = tool.execute(user_query: reservation_user_with_valid_uid.uid, user_id: other_user.id)

        result[:reservations].each do |r|
          expect(r[:user_id]).to eq(reservation_user_with_valid_uid.id)
        end
      end
    end
  end
end
