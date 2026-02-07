# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe ReservationWorker do
  let(:reservation) { create :reservation }

  context 'starting' do
    it 'should tell the server to start the reservation' do
      server = reservation.server
      allow(Reservation).to receive(:includes).and_return(Reservation)
      allow(Reservation).to receive(:find).with(reservation.id).and_return(reservation)
      expect(server).to receive(:start_reservation).with(reservation)

      ReservationWorker.new.perform(reservation.id, 'start')
    end
  end

  context 'updating' do
    describe '#update_reservation' do
      it 'should tell the server to update the reservation' do
        server = reservation.server
        allow(Reservation).to receive(:includes).and_return(Reservation)
        allow(Reservation).to receive(:find).with(reservation.id).and_return(reservation)
        expect(server).to receive(:update_reservation).with(reservation)

        ReservationWorker.new.perform(reservation.id, 'update')
      end
    end
  end

  context 'ending' do
    it 'should send the end_reservation message to the server' do
      server = reservation.server
      allow(Reservation).to receive(:includes).and_return(Reservation)
      allow(Reservation).to receive(:find).with(reservation.id).and_return(reservation)
      allow(server).to receive(:uses_async_cleanup?).and_return(false)
      expect(server).to receive(:end_reservation)

      ReservationWorker.new.perform(reservation.id, 'end')
    end

    it 'should enqueue ReservationCleanupWorker after ending reservation for async cleanup servers' do
      temp_directory = "/tmp/reservation-#{reservation.id}"
      server = reservation.server
      allow(Reservation).to receive(:includes).and_return(Reservation)
      allow(Reservation).to receive(:find).with(reservation.id).and_return(reservation)
      allow(server).to receive(:end_reservation)
      allow(server).to receive(:uses_async_cleanup?).and_return(true)
      allow(server).to receive(:temp_directory_for_reservation).and_return(temp_directory)

      expect(ReservationCleanupWorker).to receive(:perform_async).with(reservation.id, temp_directory)

      ReservationWorker.new.perform(reservation.id, 'end')
    end

    it 'should not enqueue ReservationCleanupWorker for FTP-based RemoteServers' do
      server = reservation.server
      allow(Reservation).to receive(:includes).and_return(Reservation)
      allow(Reservation).to receive(:find).with(reservation.id).and_return(reservation)
      allow(server).to receive(:end_reservation)
      expect(server).to receive(:uses_async_cleanup?).and_return(false)

      expect(ReservationCleanupWorker).not_to receive(:perform_async)

      ReservationWorker.new.perform(reservation.id, 'end')
    end
  end
end
