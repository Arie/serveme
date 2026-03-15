# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe AllowReservationPlayersWorker do
  let(:server) { create :server, ip: '127.0.0.1', port: 27015 }
  let(:reservation) { create :reservation, server: server }

  before do
    allow(server).to receive(:supports_mitigations?).and_return(true)
    allow(server).to receive(:mitigation_ssh_exec)
    allow(Reservation).to receive(:includes).and_return(Reservation)
    allow(Reservation).to receive(:find).with(reservation.id).and_return(reservation)
    allow(reservation).to receive(:server).and_return(server)
  end

  describe '#perform' do
    it 'skips SSH for players whose duplicates are already whitelisted' do
      create :reservation_player, reservation: reservation, ip: '1.2.3.4', steam_uid: 1001, whitelisted: true
      rp2 = create :reservation_player, reservation: reservation, ip: '1.2.3.4', steam_uid: 1001, whitelisted: false

      expect(server).not_to receive(:mitigation_ssh_exec)

      subject.perform(reservation.id)

      expect(rp2.reload.whitelisted).to be true
    end

    it 'does nothing when reservation has ended' do
      reservation.update_column(:ended, true)

      expect(server).not_to receive(:mitigation_ssh_exec)

      subject.perform(reservation.id)
    end

    it 'whitelists players with NULL whitelisted (created by first_or_create)' do
      rp = create :reservation_player, reservation: reservation, ip: '5.6.7.8', steam_uid: 1005, whitelisted: nil

      expect(server).to receive(:mitigation_ssh_exec).once.with(
        a_string_matching(/5\.6\.7\.8/),
        log_stderr: true
      )

      subject.perform(reservation.id)

      expect(rp.reload.whitelisted).to be true
    end

    it 'only issues SSH for players that need a new iptables rule' do
      create :reservation_player, reservation: reservation, ip: '1.2.3.4', steam_uid: 1001, whitelisted: true
      create :reservation_player, reservation: reservation, ip: '1.2.3.4', steam_uid: 1001, whitelisted: false
      rp3 = create :reservation_player, reservation: reservation, ip: '9.8.7.6', steam_uid: 1003, whitelisted: false

      expect(server).to receive(:mitigation_ssh_exec).once.with(
        a_string_matching(/9\.8\.7\.6/).and(satisfy { |s| !s.match?(/1\.2\.3\.4/) }),
        log_stderr: true
      )

      subject.perform(reservation.id)

      expect(rp3.reload.whitelisted).to be true
    end
  end
end
