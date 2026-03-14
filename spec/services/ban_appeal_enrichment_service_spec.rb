# typed: false
# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

describe BanAppealEnrichmentService do
  let(:discord_uid) { "111222333444" }

  around do |example|
    VCR.turned_off do
      WebMock.allow_net_connect!
      example.run
      WebMock.disable_net_connect!
    end
  end

  describe "#collect" do
    context "when user is found locally on EU" do
      let(:user) { create(:user, uid: "76561198012345678", nickname: "TestPlayer", discord_uid: discord_uid) }

      before do
        user
        stub_const("SITE_HOST", "serveme.tf")
        allow(ReservationPlayer).to receive(:banned_uid?).and_return("cheating")
        allow(ReservationPlayer).to receive(:banned_ip?).and_return(false)
        allow(ReservationPlayer).to receive(:whitelisted_uid?).and_return(nil)
      end

      it "returns merged data from EU and queries other regions" do
        allow(Rails.application.credentials).to receive(:dig).and_call_original
        allow(Rails.application.credentials).to receive(:dig).with(:serveme, :na).and_return("na-key")
        allow(Rails.application.credentials).to receive(:dig).with(:serveme, :sea).and_return("sea-key")
        allow(Rails.application.credentials).to receive(:dig).with(:serveme, :au).and_return("au-key")

        # Other regions return not found
        stub_request(:get, %r{direct\.na\.serveme\.tf/api/ban_appeals/user_info})
          .to_return(status: 200, body: { found: false, region: "na" }.to_json, headers: { "Content-Type" => "application/json" })
        stub_request(:get, %r{direct\.sea\.serveme\.tf/api/ban_appeals/user_info})
          .to_return(status: 200, body: { found: false, region: "sea" }.to_json, headers: { "Content-Type" => "application/json" })
        stub_request(:get, %r{direct\.au\.serveme\.tf/api/ban_appeals/user_info})
          .to_return(status: 200, body: { found: false, region: "au" }.to_json, headers: { "Content-Type" => "application/json" })

        result = described_class.new(discord_uid).collect

        expect(result[:found]).to be true
        expect(result[:steam_uid]).to eq("76561198012345678")
        expect(result[:banned]).to be true
        expect(result[:ban_reason]).to eq("cheating")
        expect(result[:ban_type]).to include("UID")
        expect(result[:regions]).to include("eu")
      end
    end

    context "when player exists only in ReservationPlayer (no User record)" do
      before do
        stub_const("SITE_HOST", "serveme.tf")
        allow(Rails.application.credentials).to receive(:dig).and_call_original
        allow(Rails.application.credentials).to receive(:dig).with(:serveme, :na).and_return("na-key")
        allow(Rails.application.credentials).to receive(:dig).with(:serveme, :sea).and_return(nil)
        allow(Rails.application.credentials).to receive(:dig).with(:serveme, :au).and_return(nil)
      end

      it "finds player data from remote region via steam_uid" do
        stub_request(:get, "https://direct.na.serveme.tf/api/ban_appeals/user_info?discord_uid=#{discord_uid}")
          .to_return(status: 200, body: {
            found: true,
            region: "na",
            steam_uid: "76561198099999999",
            nickname: "CheaterAlt",
            banned: true,
            ban_reason: "cheating",
            ban_type: [ "UID" ],
            reservation_count: 0,
            games_played: 5,
            first_seen: "2025-01-01",
            last_seen: "2025-06-01",
            ips: [ "1.2.3.4" ],
            alts: [],
            ip_lookups: [],
            stac_detections: []
          }.to_json, headers: { "Content-Type" => "application/json" })

        result = described_class.new(discord_uid).collect

        expect(result[:found]).to be true
        expect(result[:steam_uid]).to eq("76561198099999999")
        expect(result[:nickname]).to eq("CheaterAlt")
        expect(result[:regions]).to include("na")
      end
    end

    context "when user is found on remote region only" do
      before do
        stub_const("SITE_HOST", "serveme.tf")
        allow(Rails.application.credentials).to receive(:dig).and_call_original
        allow(Rails.application.credentials).to receive(:dig).with(:serveme, :na).and_return("na-key")
        allow(Rails.application.credentials).to receive(:dig).with(:serveme, :sea).and_return(nil)
        allow(Rails.application.credentials).to receive(:dig).with(:serveme, :au).and_return(nil)
      end

      it "finds user via remote region and queries others with steam_uid" do
        stub_request(:get, "https://direct.na.serveme.tf/api/ban_appeals/user_info?discord_uid=#{discord_uid}")
          .to_return(status: 200, body: {
            found: true,
            region: "na",
            steam_uid: "76561198099999999",
            nickname: "NAPlayer",
            discord_uid: discord_uid,
            banned: true,
            ban_reason: "VPN",
            reservation_count: 10,
            games_played: 15,
            first_seen: "2024-01-15",
            last_seen: "2025-12-01",
            ips: [ "1.2.3.4" ],
            alts: [],
            ip_lookups: [],
            stac_detections: []
          }.to_json, headers: { "Content-Type" => "application/json" })

        result = described_class.new(discord_uid).collect

        expect(result[:found]).to be true
        expect(result[:steam_uid]).to eq("76561198099999999")
        expect(result[:nickname]).to eq("NAPlayer")
        expect(result[:banned]).to be true
        expect(result[:ban_reason]).to eq("VPN")
        expect(result[:regions]).to include("na")
      end
    end

    context "when user is not found on any region" do
      before do
        stub_const("SITE_HOST", "serveme.tf")
        allow(Rails.application.credentials).to receive(:dig).and_call_original
        allow(Rails.application.credentials).to receive(:dig).with(:serveme, :na).and_return("na-key")
        allow(Rails.application.credentials).to receive(:dig).with(:serveme, :sea).and_return("sea-key")
        allow(Rails.application.credentials).to receive(:dig).with(:serveme, :au).and_return("au-key")
      end

      it "returns found: false" do
        stub_request(:get, %r{direct\.na\.serveme\.tf/api/ban_appeals/user_info})
          .to_return(status: 200, body: { found: false, region: "na" }.to_json, headers: { "Content-Type" => "application/json" })
        stub_request(:get, %r{direct\.sea\.serveme\.tf/api/ban_appeals/user_info})
          .to_return(status: 200, body: { found: false, region: "sea" }.to_json, headers: { "Content-Type" => "application/json" })
        stub_request(:get, %r{direct\.au\.serveme\.tf/api/ban_appeals/user_info})
          .to_return(status: 200, body: { found: false, region: "au" }.to_json, headers: { "Content-Type" => "application/json" })

        result = described_class.new(discord_uid).collect

        expect(result[:found]).to be false
      end
    end

    context "when a remote region is unreachable" do
      let(:user) { create(:user, uid: "76561198012345678", nickname: "TestPlayer", discord_uid: discord_uid) }

      before do
        user
        stub_const("SITE_HOST", "serveme.tf")
        allow(ReservationPlayer).to receive(:banned_uid?).and_return("cheating")
        allow(ReservationPlayer).to receive(:banned_ip?).and_return(false)
        allow(ReservationPlayer).to receive(:whitelisted_uid?).and_return(nil)
        allow(Rails.application.credentials).to receive(:dig).and_call_original
        allow(Rails.application.credentials).to receive(:dig).with(:serveme, :na).and_return("na-key")
        allow(Rails.application.credentials).to receive(:dig).with(:serveme, :sea).and_return("sea-key")
        allow(Rails.application.credentials).to receive(:dig).with(:serveme, :au).and_return("au-key")
      end

      it "continues with available data and logs warning" do
        stub_request(:get, %r{direct\.na\.serveme\.tf/api/ban_appeals/user_info})
          .to_raise(Faraday::ConnectionFailed.new("Connection refused"))
        stub_request(:get, %r{direct\.sea\.serveme\.tf/api/ban_appeals/user_info})
          .to_return(status: 200, body: { found: false, region: "sea" }.to_json, headers: { "Content-Type" => "application/json" })
        stub_request(:get, %r{direct\.au\.serveme\.tf/api/ban_appeals/user_info})
          .to_return(status: 200, body: { found: false, region: "au" }.to_json, headers: { "Content-Type" => "application/json" })

        expect(Rails.logger).to receive(:warn).with(/Error fetching ban appeal data from na/)

        result = described_class.new(discord_uid).collect

        expect(result[:found]).to be true
        expect(result[:regions]).to include("eu")
        expect(result[:regions]).not_to include("na")
      end
    end

    context "merging data from multiple regions" do
      let(:user) { create(:user, uid: "76561198012345678", nickname: "OldName", discord_uid: discord_uid) }

      before do
        user
        stub_const("SITE_HOST", "serveme.tf")
        reservation = create(:reservation, user: user)
        create(:reservation_player, reservation: reservation, steam_uid: user.uid, ip: "10.0.0.1", name: "OldName")

        allow(ReservationPlayer).to receive(:banned_uid?).and_return("cheating")
        allow(ReservationPlayer).to receive(:banned_ip?).and_return(false)
        allow(ReservationPlayer).to receive(:whitelisted_uid?).and_return(nil)
        allow(Rails.application.credentials).to receive(:dig).and_call_original
        allow(Rails.application.credentials).to receive(:dig).with(:serveme, :na).and_return("na-key")
        allow(Rails.application.credentials).to receive(:dig).with(:serveme, :sea).and_return(nil)
        allow(Rails.application.credentials).to receive(:dig).with(:serveme, :au).and_return(nil)
      end

      it "merges reservation counts, games played, and IPs across regions" do
        stub_request(:get, %r{direct\.na\.serveme\.tf/api/ban_appeals/user_info})
          .to_return(status: 200, body: {
            found: true,
            region: "na",
            steam_uid: "76561198012345678",
            nickname: "NewerName",
            banned: true,
            ban_reason: "cheating",
            ban_type: [ "UID" ],
            reservation_count: 25,
            games_played: 50,
            first_seen: "2023-06-01",
            last_seen: "2026-03-01",
            ips: [ "20.0.0.1" ],
            alts: [
              { steam_uid: "76561198099999999", name: "AltOnNA", reservation_count: 5, banned: false }
            ],
            ip_lookups: [
              { ip: "20.0.0.1", fraud_score: 10, is_proxy: false, isp: "Comcast", country_code: "US" }
            ],
            stac_detections: []
          }.to_json, headers: { "Content-Type" => "application/json" })

        result = described_class.new(discord_uid).collect

        expect(result[:found]).to be true
        expect(result[:regions]).to contain_exactly("eu", "na")
        expect(result[:reservation_count]).to be > 1
        expect(result[:games_played]).to be > 1
        expect(result[:alts]).to be_an(Array)
        expect(result[:stac_detections]).to be_an(Array)
        expect(result[:ban_type]).to include("UID")
      end

      it "uses the most recent nickname" do
        stub_request(:get, %r{direct\.na\.serveme\.tf/api/ban_appeals/user_info})
          .to_return(status: 200, body: {
            found: true,
            region: "na",
            steam_uid: "76561198012345678",
            nickname: "NewerName",
            banned: true,
            ban_reason: "cheating",
            reservation_count: 5,
            games_played: 10,
            first_seen: "2023-06-01",
            last_seen: "2099-01-01T00:00:00Z",
            ips: [],
            alts: [],
            ip_lookups: [],
            stac_detections: []
          }.to_json, headers: { "Content-Type" => "application/json" })

        result = described_class.new(discord_uid).collect

        # NA has more recent last_seen, so its nickname wins
        expect(result[:nickname]).to eq("NewerName")
      end
    end

    context "when credentials are missing for a region" do
      let(:user) { create(:user, uid: "76561198012345678", nickname: "TestPlayer", discord_uid: discord_uid) }

      before do
        user
        stub_const("SITE_HOST", "serveme.tf")
        allow(ReservationPlayer).to receive(:banned_uid?).and_return("cheating")
        allow(ReservationPlayer).to receive(:banned_ip?).and_return(false)
        allow(ReservationPlayer).to receive(:whitelisted_uid?).and_return(nil)
        allow(Rails.application.credentials).to receive(:dig).and_call_original
        allow(Rails.application.credentials).to receive(:dig).with(:serveme, :na).and_return(nil)
        allow(Rails.application.credentials).to receive(:dig).with(:serveme, :sea).and_return(nil)
        allow(Rails.application.credentials).to receive(:dig).with(:serveme, :au).and_return(nil)
      end

      it "skips regions with missing credentials" do
        result = described_class.new(discord_uid).collect

        expect(result[:found]).to be true
        expect(result[:regions]).to eq([ "eu" ])
        expect(WebMock).not_to have_requested(:get, %r{direct\.na\.serveme\.tf})
      end
    end
  end
end
