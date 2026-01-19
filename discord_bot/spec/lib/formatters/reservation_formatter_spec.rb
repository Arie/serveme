# typed: false
# frozen_string_literal: true

require_relative "../../spec_helper"

RSpec.describe ServemeBot::Formatters::ReservationFormatter do
  describe ".format_reservation_list" do
    it "returns empty embed when no reservations" do
      data = { reservations: [] }

      embed = described_class.format_reservation_list(data)

      expect(embed[:title]).to eq("Your Reservations")
      expect(embed[:description]).to eq("No reservations found.")
    end

    it "formats reservations with server name and map" do
      data = {
        reservations: [
          {
            "server_name" => "TestBrigade #01",
            "first_map" => "cp_badlands",
            "starts_at" => "2025-01-15T10:00:00Z",
            "ends_at" => "2025-01-15T12:00:00Z",
            "status" => "past",
            "region_flag" => "🇪🇺"
          }
        ]
      }

      embed = described_class.format_reservation_list(data)

      expect(embed[:description]).to include("TestBrigade #01")
      expect(embed[:description]).to include("cp_badlands")
      expect(embed[:description]).to include("🇪🇺")
    end

    it "limits to 10 reservations" do
      reservations = (1..15).map do |i|
        {
          "server_name" => "Server #{i}",
          "first_map" => "cp_badlands",
          "starts_at" => "2025-01-15T10:00:00Z",
          "status" => "past"
        }
      end
      data = { reservations: reservations }

      embed = described_class.format_reservation_list(data)

      expect(embed[:description]).to include("Server 1")
      expect(embed[:description]).to include("Server 10")
      expect(embed[:description]).not_to include("Server 11")
      expect(embed[:description]).to include("...and 5 more")
    end

    it "includes player info in author when provided" do
      data = {
        player: { "nickname" => "TestPlayer", "steam_profile_url" => "https://steamcommunity.com/id/test" },
        reservations: [
          { "server_name" => "Server", "starts_at" => "2025-01-15T10:00:00Z", "status" => "past" }
        ]
      }

      embed = described_class.format_reservation_list(data)

      expect(embed[:author][:name]).to eq("TestPlayer")
      expect(embed[:author][:url]).to eq("https://steamcommunity.com/id/test")
    end
  end

  describe ".format_reservation_line" do
    it "formats a past reservation" do
      res = {
        "server_name" => "TestBrigade #01",
        "first_map" => "cp_process",
        "starts_at" => "2025-01-15T10:00:00Z",
        "ends_at" => "2025-01-15T12:00:00Z",
        "status" => "past",
        "region_flag" => "🇪🇺"
      }

      line = described_class.format_reservation_line(res)

      expect(line).to include("🇪🇺")
      expect(line).to include("**TestBrigade #01**")
      expect(line).to include("`cp_process`")
      expect(line).to include("Jan 15, 2025")
    end

    it "formats a current reservation" do
      res = {
        "server_name" => "TestBrigade #01",
        "first_map" => "cp_process",
        "starts_at" => Time.now.iso8601,
        "ends_at" => (Time.now + 3600).iso8601,
        "status" => "current",
        "region_flag" => "🇪🇺"
      }

      line = described_class.format_reservation_line(res)

      expect(line).to include("Now - ends")
    end
  end
end
