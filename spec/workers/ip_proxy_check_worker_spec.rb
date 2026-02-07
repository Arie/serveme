# typed: false
# frozen_string_literal: true

require "spec_helper"

describe IpProxyCheckWorker do
  let(:steam_uid) { 76561198000000001 }
  let(:ip) { "47.154.67.194" }
  let(:player_uid) { 3 }
  let(:reservation_player) { double(:reservation_player, id: 1, steam_uid: steam_uid.to_s, ip: ip, name: "TestPlayer") }

  describe "#perform" do
    before do
      allow(ReservationPlayer).to receive(:find_by).with(id: reservation_player.id).and_return(reservation_player)
      allow(ReservationPlayer).to receive(:sdr_ip?).with(ip).and_return(false)
      allow(ReservationPlayer).to receive(:banned_asn_ip?).with(ip).and_return(false)
      allow(ReservationPlayer).to receive(:whitelisted_uid?).with(steam_uid).and_return(false)
    end

    context "when player should be checked" do
      it "skips if IP is already cached" do
        allow(IpLookup).to receive(:cached?).with(ip).and_return(true)
        expect(ProxyDetectionService).not_to receive(:check)

        described_class.new.perform(reservation_player.id, player_uid)
      end

      it "skips if player has history (> 1 month)" do
        allow(IpLookup).to receive(:cached?).with(ip).and_return(false)
        allow(ReservationPlayer).to receive_message_chain(:joins, :where, :where, :exists?).and_return(true)
        expect(ProxyDetectionService).not_to receive(:check)

        described_class.new.perform(reservation_player.id, player_uid)
      end

      it "calls ProxyDetectionService to check the IP" do
        allow(IpLookup).to receive(:cached?).with(ip).and_return(false)
        allow(ReservationPlayer).to receive_message_chain(:joins, :where, :where, :exists?).and_return(false)
        expect(ProxyDetectionService).to receive(:check).with(ip)

        described_class.new.perform(reservation_player.id, player_uid)
      end
    end

    context "when player should be skipped" do
      it "skips SDR IPs" do
        sdr_ip = "169.254.1.1"
        sdr_rp = double(:reservation_player, id: 2, steam_uid: steam_uid.to_s, ip: sdr_ip, name: "SDRPlayer")
        allow(ReservationPlayer).to receive(:find_by).with(id: sdr_rp.id).and_return(sdr_rp)
        allow(ReservationPlayer).to receive(:sdr_ip?).with(sdr_ip).and_return(true)
        expect(ProxyDetectionService).not_to receive(:check)

        described_class.new.perform(sdr_rp.id, player_uid)
      end

      it "skips banned ASN IPs (already handled by VPN check)" do
        allow(ReservationPlayer).to receive(:banned_asn_ip?).with(ip).and_return(true)
        expect(ProxyDetectionService).not_to receive(:check)

        described_class.new.perform(reservation_player.id, player_uid)
      end

      it "skips whitelisted players" do
        allow(ReservationPlayer).to receive(:whitelisted_uid?).with(steam_uid).and_return(true)
        expect(ProxyDetectionService).not_to receive(:check)

        described_class.new.perform(reservation_player.id, player_uid)
      end
    end

    context "when reservation player has no IP" do
      it "does nothing" do
        rp_no_ip = double(:reservation_player, id: 3, steam_uid: steam_uid.to_s, ip: nil)
        allow(ReservationPlayer).to receive(:find_by).with(id: rp_no_ip.id).and_return(rp_no_ip)
        expect(ProxyDetectionService).not_to receive(:check)

        described_class.new.perform(rp_no_ip.id, player_uid)
      end
    end

    context "when all providers are exhausted" do
      it "logs warning but does not crash" do
        allow(IpLookup).to receive(:cached?).with(ip).and_return(false)
        allow(ReservationPlayer).to receive_message_chain(:joins, :where, :where, :exists?).and_return(false)
        allow(ProxyDetectionService).to receive(:check).and_raise(ProxyDetectionService::AllProvidersExhaustedError.new("All providers failed"))
        expect(Rails.logger).to receive(:warn).with(/All providers exhausted/)

        described_class.new.perform(reservation_player.id, player_uid)
      end
    end
  end
end
