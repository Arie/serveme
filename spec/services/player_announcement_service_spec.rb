# typed: false
# frozen_string_literal: true

require "spec_helper"

describe PlayerAnnouncementService do
  let(:steam_uid) { 76561198012345678 }
  let(:ip) { "85.139.95.110" }

  before do
    allow(Geocoder).to receive(:search).and_return([])
    allow(ReservationPlayer).to receive(:asn).and_return(nil)
  end

  describe ".build_info" do
    it "returns 'First game' for a brand new player" do
      expect(described_class.build_info(steam_uid, ip)).to eq("First game")
    end

    it "includes location and ISP" do
      geocode_result = double(state: "North Rhine-Westphalia", country: "Germany")
      allow(Geocoder).to receive(:search).with(ip).and_return([ geocode_result ])

      asn_data = double(autonomous_system_organization: "Deutsche Telekom")
      allow(ReservationPlayer).to receive(:asn).with(ip).and_return(asn_data)

      result = described_class.build_info(steam_uid, ip)
      expect(result).to include("North Rhine-Westphalia, Germany")
      expect(result).to include("Deutsche Telekom")
      expect(result).to include("First game")
    end

    it "uses ASN organization from ReservationPlayer record when available" do
      rp = create(:reservation_player, steam_uid: steam_uid, ip: ip)
      rp.update_column(:asn_organization, "Cached ISP")

      result = described_class.build_info(steam_uid, ip)
      expect(result).to include("Cached ISP")
    end

    it "falls back to live ASN lookup when no record exists" do
      asn_data = double(autonomous_system_organization: "Live ISP")
      allow(ReservationPlayer).to receive(:asn).with(ip).and_return(asn_data)

      result = described_class.build_info(steam_uid, ip)
      expect(result).to include("Live ISP")
    end

    it "shows SDR for SDR IPs" do
      result = described_class.build_info(steam_uid, "169.254.1.1")
      expect(result).to start_with("SDR")
    end

    it "includes first seen month/year and game count" do
      user = create(:user)
      server = create(:server)
      old_reservation = build(:reservation, user: user, server: server, starts_at: 2.weeks.ago, ends_at: 2.weeks.ago + 2.hours)
      old_reservation.save(validate: false)
      create(:reservation_player, reservation: old_reservation, steam_uid: steam_uid, ip: ip)

      result = described_class.build_info(steam_uid, ip)
      expect(result).to include("First seen: #{2.weeks.ago.strftime('%B %Y')}")
      expect(result).to include("Games: 1")
    end

    it "includes VPN attempt count" do
      banned_asn = ReservationPlayer.banned_asns.first
      rp = create(:reservation_player, steam_uid: steam_uid, ip: "1.2.3.4")
      rp.update_column(:asn_number, banned_asn)

      result = described_class.build_info(steam_uid, ip)
      expect(result).to include("VPN attempts: 1")
    end

    context "ETF2L league data (EU)" do
      before { stub_const("SITE_HOST", "serveme.tf") }

      it "includes highest ETF2L division from season competitions" do
        etf2l_json = {
          "player" => {
            "name" => "TestPlayer",
            "bans" => [],
            "teams" => [
              {
                "name" => "SomeTeam",
                "competitions" => {
                  "1" => { "category" => "6v6 Season", "competition" => "Season 20", "division" => { "name" => "Division 2", "tier" => 2 } },
                  "2" => { "category" => "6v6 Season", "competition" => "Season 9", "division" => { "name" => "Premiership", "tier" => 0 } },
                  "3" => { "category" => "6v6 Cup", "competition" => "Nations Cup #5", "division" => { "name" => "Premiership", "tier" => 0 } }
                }
              }
            ]
          }
        }
        allow(Etf2lApi).to receive(:profile).and_return(etf2l_json.to_json)

        result = described_class.build_info(steam_uid, ip)
        expect(result).to include("ETF2L: Premiership (S9)")
        expect(result).not_to include("Nations Cup")
      end

      it "includes ETF2L ban info" do
        etf2l_json = {
          "player" => {
            "name" => "Cheater",
            "bans" => [ { "reason" => "Cheating", "start" => 1.day.ago.to_i, "end" => 1.year.from_now.to_i } ],
            "teams" => []
          }
        }
        allow(Etf2lApi).to receive(:profile).and_return(etf2l_json.to_json)

        result = described_class.build_info(steam_uid, ip)
        expect(result).to include("ETF2L ban: Cheating")
      end

      it "handles ETF2L API timeout gracefully" do
        allow(Etf2lApi).to receive(:profile).and_raise(Faraday::TimeoutError)

        result = described_class.build_info(steam_uid, ip)
        expect(result).to eq("First game")
      end
    end

    context "RGL league data (NA)" do
      before { stub_const("SITE_HOST", "na.serveme.tf") }

      it "includes RGL ban info" do
        rgl_json = {
          "name" => "BannedPlayer",
          "status" => { "isBanned" => true },
          "banInformation" => { "reason" => "Match fixing", "endsAt" => 1.year.from_now.iso8601 }
        }
        allow(RglApi).to receive(:profile).and_return(rgl_json.to_json)

        result = described_class.build_info(steam_uid, ip)
        expect(result).to include("RGL ban: Match fixing")
      end

      it "does not include league info for unbanned RGL player" do
        rgl_json = {
          "name" => "CleanPlayer",
          "status" => { "isBanned" => false },
          "banInformation" => nil,
          "currentTeams" => { "sixes" => nil, "highlander" => nil }
        }
        allow(RglApi).to receive(:profile).and_return(rgl_json.to_json)

        result = described_class.build_info(steam_uid, ip)
        expect(result).not_to include("RGL")
      end
    end

    context "alt detection" do
      it "includes possible alts when another account shares an IP" do
        user = create(:user)
        server = create(:server, sdr: false)
        reservation = build(:reservation, user: user, server: server, starts_at: 1.week.ago, ends_at: 1.week.ago + 2.hours)
        reservation.save(validate: false)

        create(:reservation_player, reservation: reservation, steam_uid: steam_uid, ip: ip)
        create(:reservation_player, reservation: reservation, steam_uid: 76561198099999999, ip: ip, name: "SuspiciousAlt")

        result = described_class.build_info(steam_uid, ip)
        expect(result).to include("Possible alts: SuspiciousAlt (76561198099999999)")
      end

      it "does not include alts from VPN IPs" do
        banned_asn = ReservationPlayer.banned_asns.first
        user = create(:user)
        server = create(:server, sdr: false)
        reservation = build(:reservation, user: user, server: server, starts_at: 1.week.ago, ends_at: 1.week.ago + 2.hours)
        reservation.save(validate: false)

        rp = create(:reservation_player, reservation: reservation, steam_uid: steam_uid, ip: "10.0.0.1")
        rp.update_column(:asn_number, banned_asn)
        create(:reservation_player, reservation: reservation, steam_uid: 76561198099999999, ip: "10.0.0.1", name: "VPNUser")

        result = described_class.build_info(steam_uid, ip)
        expect(result).not_to include("Possible alts")
      end

      it "does not show alts section when there are none" do
        result = described_class.build_info(steam_uid, ip)
        expect(result).not_to include("Possible alts")
      end
    end

    context "ozfortress league data (AU)" do
      before { stub_const("SITE_HOST", "au.serveme.tf") }

      it "includes highest ozfortress division" do
        ozf_json = {
          "user" => {
            "name" => "AUPlayer",
            "rosters" => [
              { "name" => "team1", "division" => "Open" },
              { "name" => "team2", "division" => "Intermediate" },
              { "name" => "team3", "division" => "Main" }
            ]
          }
        }
        allow(OzfortressApi).to receive(:profile).and_return(ozf_json.to_json)

        result = described_class.build_info(steam_uid, ip)
        expect(result).to include("ozfortress: Intermediate")
      end

      it "handles player with no ozfortress profile" do
        allow(OzfortressApi).to receive(:profile).and_return(nil)

        result = described_class.build_info(steam_uid, ip)
        expect(result).not_to include("ozfortress")
      end
    end
  end
end
