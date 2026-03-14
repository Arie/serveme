# typed: false
# frozen_string_literal: true

require "spec_helper"

describe Api::BanAppealsController do
  render_views

  describe "#user_info" do
    context "without authentication" do
      it "returns unauthorized" do
        get :user_info, format: :json, params: { steam_uid: "76561198012345678" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with regular user" do
      let(:user) { create(:user) }

      before do
        allow(controller).to receive(:api_user).and_return(user)
      end

      it "returns forbidden" do
        get :user_info, format: :json, params: { steam_uid: "76561198012345678" }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with admin user" do
      let(:admin) { create(:user, :admin) }

      before do
        allow(controller).to receive(:api_user).and_return(admin)
      end

      context "when looking up by steam_uid with User record" do
        let(:target_user) { create(:user, uid: "76561198012345678", nickname: "BannedPlayer", discord_uid: "111222333") }

        it "returns user info when found" do
          target_user
          reservation = create(:reservation, user: target_user)
          create(:reservation_player, reservation: reservation, steam_uid: target_user.uid, ip: "1.2.3.4", name: "InGameName")

          allow(ReservationPlayer).to receive(:banned_uid?).and_return("cheating")
          allow(ReservationPlayer).to receive(:banned_ip?).and_return(false)
          allow(ReservationPlayer).to receive(:whitelisted_uid?).and_return(nil)

          get :user_info, format: :json, params: { steam_uid: "76561198012345678" }

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json["found"]).to be true
          expect(json["steam_uid"]).to eq("76561198012345678")
          expect(json["nickname"]).to eq("InGameName")
          expect(json["discord_uid"]).to eq("111222333")
          expect(json["banned"]).to be true
          expect(json["ban_reason"]).to eq("cheating")
          expect(json["ban_type"]).to include("UID")
          expect(json["games_played"]).to eq(1)
          expect(json["stac_detections"]).to be_an(Array)
        end
      end

      context "when looking up by steam_uid without User record" do
        it "returns data from ReservationPlayer records" do
          other_user = create(:user)
          reservation = create(:reservation, user: other_user)
          create(:reservation_player, reservation: reservation, steam_uid: "76561198012345678", ip: "5.6.7.8", name: "CheaterName")

          allow(ReservationPlayer).to receive(:banned_uid?).and_return("cheating")
          allow(ReservationPlayer).to receive(:banned_ip?).and_return(false)
          allow(ReservationPlayer).to receive(:whitelisted_uid?).and_return(nil)

          get :user_info, format: :json, params: { steam_uid: "76561198012345678" }

          json = JSON.parse(response.body)
          expect(json["found"]).to be true
          expect(json["steam_uid"]).to eq("76561198012345678")
          expect(json["nickname"]).to eq("CheaterName")
          expect(json["banned"]).to be true
          expect(json["reservation_count"]).to eq(0)
          expect(json["games_played"]).to eq(1)
        end
      end

      context "when neither User nor ReservationPlayer exists" do
        it "returns not found" do
          allow(ReservationPlayer).to receive(:banned_uid?).and_return(nil)

          get :user_info, format: :json, params: { steam_uid: "76561198099999999" }

          json = JSON.parse(response.body)
          expect(json["found"]).to be false
        end
      end

      it "includes reservation stats" do
        target_user = create(:user, uid: "76561198012345678", nickname: "Player")
        reservation = create(:reservation, user: target_user)
        create(:reservation_player, reservation: reservation, steam_uid: target_user.uid, ip: "1.2.3.4", name: "Player")

        allow(ReservationPlayer).to receive(:banned_uid?).and_return(nil)
        allow(ReservationPlayer).to receive(:banned_ip?).and_return(false)
        allow(ReservationPlayer).to receive(:whitelisted_uid?).and_return(nil)

        get :user_info, format: :json, params: { steam_uid: "76561198012345678" }

        json = JSON.parse(response.body)
        expect(json["reservation_count"]).to eq(1)
        expect(json["games_played"]).to eq(1)
        expect(json["ips"]).to be_an(Array)
      end

      context "when looking up by discord_uid" do
        let(:target_user) { create(:user, uid: "76561198012345678", nickname: "DiscordPlayer", discord_uid: "444555666") }

        it "returns user info when found by discord_uid" do
          target_user

          allow(ReservationPlayer).to receive(:banned_uid?).and_return(nil)
          allow(ReservationPlayer).to receive(:banned_ip?).and_return(false)
          allow(ReservationPlayer).to receive(:whitelisted_uid?).and_return(nil)

          get :user_info, format: :json, params: { discord_uid: "444555666" }

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json["found"]).to be true
          expect(json["steam_uid"]).to eq("76561198012345678")
        end

        it "returns not found when discord_uid not linked" do
          get :user_info, format: :json, params: { discord_uid: "999888777" }

          json = JSON.parse(response.body)
          expect(json["found"]).to be false
        end
      end

      it "returns bad request when neither steam_uid nor discord_uid provided" do
        get :user_info, format: :json

        expect(response).to have_http_status(:bad_request)
      end

      context "with IP lookup data" do
        it "includes ip lookup information" do
          other_user = create(:user)
          reservation = create(:reservation, user: other_user)
          create(:reservation_player, reservation: reservation, steam_uid: "76561198012345678", ip: "5.6.7.8", name: "Player")
          IpLookup.create!(ip: "5.6.7.8", fraud_score: 85, is_proxy: true, isp: "VPNProvider", country_code: "DE")

          allow(ReservationPlayer).to receive(:banned_uid?).and_return(nil)
          allow(ReservationPlayer).to receive(:banned_ip?).and_return(false)
          allow(ReservationPlayer).to receive(:whitelisted_uid?).and_return(nil)

          get :user_info, format: :json, params: { steam_uid: "76561198012345678" }

          json = JSON.parse(response.body)
          expect(json["ip_lookups"]).to be_an(Array)
          ip_info = json["ip_lookups"].find { |l| l["ip"] == "5.6.7.8" }
          expect(ip_info["fraud_score"]).to eq(85)
          expect(ip_info["is_proxy"]).to be true
          expect(ip_info["isp"]).to eq("VPNProvider")
        end
      end
    end
  end
end
