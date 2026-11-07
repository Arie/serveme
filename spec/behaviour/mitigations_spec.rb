# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe Mitigations do
  let(:server) { create(:server, port: '27015') }
  let(:reservation) { create(:reservation, server: server) }
  let(:commands) { [] }

  before do
    allow(server).to receive(:sdr?).and_return(false)
    allow(server).to receive(:mitigation_ssh_exec) { |command, **| commands << command; "" }
    allow(reservation).to receive(:server).and_return(server)
  end

  describe '#enable_mitigations' do
    it 'sets up a rate limited chain for the server port' do
      reservation.enable_mitigations
      command = commands.join

      expect(command).to include('sudo iptables -w 5 -t raw --flush serveme-27015;')
      expect(command).to include('-A serveme-27015 -t raw -p tcp -m limit --limit 100/s --limit-burst 100 -j ACCEPT')
      expect(command).to include('-A serveme-27015 -t raw -p udp -m limit --limit 300/s --limit-burst 300 -j ACCEPT')
      expect(command).to include('-A serveme-27015 -t raw -j DROP')
      expect(command).to include('-A PREROUTING -t raw -p udp --destination-port 27015 -j serveme-27015')
      expect(command).to include(%(-I serveme-27015 1 -t raw -s #{DIRECT_HOST} -j ACCEPT -m comment --comment "serveme-27015-system"))
    end

    it 'skips the UDP allowance for SDR servers' do
      allow(server).to receive(:sdr?).and_return(true)

      reservation.enable_mitigations

      expect(commands.join).not_to include('-p udp -m limit')
    end
  end

  describe '#allow_reservation_player' do
    let(:player) { create(:reservation_player, reservation: reservation, steam_uid: '76561197960497430', ip: '1.2.3.4') }

    it 'allows the player IP and marks them allowed' do
      reservation.allow_reservation_player(player)

      expect(commands.join).to include(%(-I serveme-27015 1 -t raw -s 1.2.3.4 -j ACCEPT -m comment --comment "serveme-27015-76561197960497430"))
      expect(player.reload.whitelisted).to be true
    end

    it 'does not add a second rule for an already allowed duplicate' do
      create(:reservation_player, reservation: reservation, steam_uid: player.steam_uid, ip: player.ip, whitelisted: true)

      reservation.allow_reservation_player(player)

      expect(commands).to be_empty
      expect(player.reload.whitelisted).to be true
    end

    it 'shell escapes the IP' do
      player.update_column(:ip, '1.2.3.4;reboot')

      reservation.allow_reservation_player(player)

      expect(commands.join).to include('-s 1.2.3.4\;reboot ')
    end
  end
end
