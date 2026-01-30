# typed: false
# frozen_string_literal: true

require "spec_helper"

describe IpProxyCheckWorker do
  let(:server) { double(:server) }
  let(:reservation) { double(:reservation, id: 1, server: server) }
  let(:steam_uid) { 76561198000000001 }
  let(:ip) { "47.154.67.194" }
  let(:player_uid) { 3 }
  let(:reservation_player) { double(:reservation_player, id: 1, steam_uid: steam_uid.to_s, ip: ip, name: "TestPlayer") }

  describe "#perform" do
    before do
      allow(ReservationPlayer).to receive(:find_by).with(id: reservation_player.id).and_return(reservation_player)
      allow(reservation_player).to receive(:reservation).and_return(reservation)
      allow(reservation).to receive(:ended?).and_return(false)
      allow(ReservationPlayer).to receive(:sdr_ip?).with(ip).and_return(false)
      allow(ReservationPlayer).to receive(:banned_asn_ip?).with(ip).and_return(false)
      allow(ReservationPlayer).to receive(:whitelisted_uid?).with(steam_uid).and_return(false)
    end

    context "when player should be checked" do
      let(:ip_lookup) { double(:ip_lookup, is_residential_proxy: false) }

      it "skips if IP is already cached" do
        allow(IpLookup).to receive(:cached?).with(ip).and_return(true)
        expect(IpQualityScoreService).not_to receive(:check)

        described_class.new.perform(reservation_player.id, player_uid)
      end

      it "skips if player has history (> 1 month)" do
        allow(IpLookup).to receive(:cached?).with(ip).and_return(false)
        allow(ReservationPlayer).to receive_message_chain(:joins, :where, :where, :exists?).and_return(true)
        expect(IpQualityScoreService).not_to receive(:check)

        described_class.new.perform(reservation_player.id, player_uid)
      end

      it "checks IP and does not kick for clean IPs" do
        allow(IpLookup).to receive(:cached?).with(ip).and_return(false)
        allow(ReservationPlayer).to receive_message_chain(:joins, :where, :where, :exists?).and_return(false)
        allow(IpQualityScoreService).to receive(:check).with(ip).and_return(ip_lookup)
        expect(server).not_to receive(:rcon_exec)

        described_class.new.perform(reservation_player.id, player_uid)
      end

      it "kicks player when residential proxy is detected" do
        residential_proxy_lookup = double(:ip_lookup, is_residential_proxy: true)
        allow(IpLookup).to receive(:cached?).with(ip).and_return(false)
        allow(ReservationPlayer).to receive_message_chain(:joins, :where, :where, :exists?).and_return(false)
        allow(IpQualityScoreService).to receive(:check).with(ip).and_return(residential_proxy_lookup)

        expect(server).to receive(:rcon_exec).with("kickid #{player_uid} [#{SITE_HOST}] Residential proxy detected; addip 0 #{ip}")
        expect(Rails.logger).to receive(:warn).with(/Kicked residential proxy/)

        described_class.new.perform(reservation_player.id, player_uid)
      end
    end

    context "when player should be skipped" do
      it "skips SDR IPs" do
        sdr_ip = "169.254.1.1"
        sdr_rp = double(:reservation_player, id: 2, steam_uid: steam_uid.to_s, ip: sdr_ip, name: "SDRPlayer")
        allow(ReservationPlayer).to receive(:find_by).with(id: sdr_rp.id).and_return(sdr_rp)
        allow(ReservationPlayer).to receive(:sdr_ip?).with(sdr_ip).and_return(true)
        expect(IpQualityScoreService).not_to receive(:check)

        described_class.new.perform(sdr_rp.id, player_uid)
      end

      it "skips banned ASN IPs (already handled by VPN check)" do
        allow(ReservationPlayer).to receive(:banned_asn_ip?).with(ip).and_return(true)
        expect(IpQualityScoreService).not_to receive(:check)

        described_class.new.perform(reservation_player.id, player_uid)
      end

      it "skips whitelisted players" do
        allow(ReservationPlayer).to receive(:whitelisted_uid?).with(steam_uid).and_return(true)
        expect(IpQualityScoreService).not_to receive(:check)

        described_class.new.perform(reservation_player.id, player_uid)
      end
    end

    context "when reservation player has no IP" do
      it "does nothing" do
        rp_no_ip = double(:reservation_player, id: 3, steam_uid: steam_uid.to_s, ip: nil)
        allow(ReservationPlayer).to receive(:find_by).with(id: rp_no_ip.id).and_return(rp_no_ip)
        expect(IpQualityScoreService).not_to receive(:check)

        described_class.new.perform(rp_no_ip.id, player_uid)
      end
    end

    context "when quota is exceeded" do
      it "logs info but does not crash" do
        allow(IpLookup).to receive(:cached?).with(ip).and_return(false)
        allow(ReservationPlayer).to receive_message_chain(:joins, :where, :where, :exists?).and_return(false)
        allow(IpQualityScoreService).to receive(:check).and_raise(IpQualityScoreService::QuotaExceededError)
        expect(Rails.logger).to receive(:info).with(/Monthly quota exceeded/)

        described_class.new.perform(reservation_player.id, player_uid)
      end
    end

    context "when API returns an error" do
      it "logs warning but does not crash" do
        allow(IpLookup).to receive(:cached?).with(ip).and_return(false)
        allow(ReservationPlayer).to receive_message_chain(:joins, :where, :where, :exists?).and_return(false)
        allow(IpQualityScoreService).to receive(:check).and_raise(IpQualityScoreService::ApiError.new("API error"))
        expect(Rails.logger).to receive(:warn).with(/API error/)

        described_class.new.perform(reservation_player.id, player_uid)
      end
    end

    context "when RCON fails" do
      it "logs warning but does not crash" do
        residential_proxy_lookup = double(:ip_lookup, is_residential_proxy: true)
        allow(IpLookup).to receive(:cached?).with(ip).and_return(false)
        allow(ReservationPlayer).to receive_message_chain(:joins, :where, :where, :exists?).and_return(false)
        allow(IpQualityScoreService).to receive(:check).with(ip).and_return(residential_proxy_lookup)

        allow(server).to receive(:rcon_exec).and_raise(SteamCondenser::Error.new("Connection failed"))
        expect(Rails.logger).to receive(:warn).with(/Failed to kick player/)

        described_class.new.perform(reservation_player.id, player_uid)
      end
    end
  end
end
