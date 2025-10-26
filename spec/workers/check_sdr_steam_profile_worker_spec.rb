# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe CheckSdrSteamProfileWorker do
  let(:server) { double(:server) }
  let(:reservation) { double(:reservation, id: 1, server: server) }
  let(:steam_uid) { 76561198000000001 }
  let(:ip) { '169.254.1.1' }
  let(:reservation_player) { double(:reservation_player, id: 1, steam_uid: steam_uid.to_s, ip: ip, name: 'TestPlayer') }

  let(:rcon_status_output) do
    'hostname: Test Server
version : 2406664/24 2406664 secure
map     : koth_pro_viaduct_rc4

# userid name                uniqueid            connected ping loss state  adr
#      3 "TestPlayer"        [U:1:39734273]      11:49       57    0 active 169.254.1.1:27005'
  end

  describe '#perform' do
    context 'when reservation is active' do
      it 'kicks player with ineligible Steam profile and marks as unwhitelisted' do
        allow(ReservationPlayer).to receive(:find_by).with(id: reservation_player.id).and_return(reservation_player)
        allow(reservation_player).to receive(:reservation).and_return(reservation)
        allow(reservation_player).to receive(:update).with(whitelisted: false).and_return(true)
        allow(ReservationPlayer).to receive(:sdr_eligible_steam_profile?).with(steam_uid).and_return(false)
        allow(reservation).to receive(:ended?).and_return(false)

        server_info = double(:server_info)
        allow(server).to receive(:server_info).and_return(server_info)
        allow(server_info).to receive(:fetch_rcon_status).and_return(rcon_status_output)

        expect(server).to receive(:rcon_exec).with("kickid 3 SDR requires public Steam profile 6+ months old; addip 1 #{ip}")
        expect(reservation_player).to receive(:update).with(whitelisted: false)
        expect(Rails.logger).to receive(:info).with(/Kicked SDR player.*Reservation ##{reservation.id}/)

        described_class.new.perform(reservation_player.id)
      end

      it 'does not kick player with eligible Steam profile' do
        allow(ReservationPlayer).to receive(:find_by).with(id: reservation_player.id).and_return(reservation_player)
        allow(reservation_player).to receive(:reservation).and_return(reservation)
        allow(ReservationPlayer).to receive(:sdr_eligible_steam_profile?).with(steam_uid).and_return(true)
        allow(reservation).to receive(:ended?).and_return(false)
        expect(server).not_to receive(:rcon_exec)

        described_class.new.perform(reservation_player.id)
      end

      it 'does nothing if player is no longer connected' do
        allow(ReservationPlayer).to receive(:find_by).with(id: reservation_player.id).and_return(reservation_player)
        allow(reservation_player).to receive(:reservation).and_return(reservation)
        allow(ReservationPlayer).to receive(:sdr_eligible_steam_profile?).with(steam_uid).and_return(false)
        allow(reservation).to receive(:ended?).and_return(false)

        server_info = double(:server_info)
        allow(server).to receive(:server_info).and_return(server_info)
        # Different player in RCON status
        allow(server_info).to receive(:fetch_rcon_status).and_return('hostname: Test Server
# userid name                uniqueid            connected ping loss state  adr
#      4 "OtherPlayer"       [U:1:99999999]      11:49       57    0 active 1.128.0.1:27005')

        expect(server).not_to receive(:rcon_exec)

        described_class.new.perform(reservation_player.id)
      end
    end

    context 'when reservation player does not exist' do
      it 'does nothing' do
        allow(ReservationPlayer).to receive(:find_by).with(id: 999999).and_return(nil)
        expect(ReservationPlayer).not_to receive(:sdr_eligible_steam_profile?)

        described_class.new.perform(999999)
      end
    end

    context 'when reservation has ended' do
      it 'does not check profile or kick player' do
        allow(ReservationPlayer).to receive(:find_by).with(id: reservation_player.id).and_return(reservation_player)
        allow(reservation_player).to receive(:reservation).and_return(reservation)
        allow(reservation).to receive(:ended?).and_return(true)
        expect(ReservationPlayer).not_to receive(:sdr_eligible_steam_profile?)
        expect(server).not_to receive(:rcon_exec)

        described_class.new.perform(reservation_player.id)
      end
    end

    context 'when RCON fails' do
      it 'logs warning but does not crash' do
        allow(ReservationPlayer).to receive(:find_by).with(id: reservation_player.id).and_return(reservation_player)
        allow(reservation_player).to receive(:reservation).and_return(reservation)
        allow(ReservationPlayer).to receive(:sdr_eligible_steam_profile?).with(steam_uid).and_return(false)
        allow(reservation).to receive(:ended?).and_return(false)

        server_info = double(:server_info)
        allow(server).to receive(:server_info).and_return(server_info)
        allow(server_info).to receive(:fetch_rcon_status).and_raise(SteamCondenser::Error.new('Connection failed'))

        expect(Rails.logger).to receive(:warn).with(/Failed to kick SDR player.*Reservation ##{reservation.id}/)

        described_class.new.perform(reservation_player.id)
      end
    end
  end
end
