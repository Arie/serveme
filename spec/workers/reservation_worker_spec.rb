# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe ReservationWorker do
  let(:reservation) { create :reservation }

  context 'starting' do
    it 'should tell the server to start the reservation' do
      Server.any_instance.should_receive(:start_reservation).with(reservation)
      ReservationWorker.perform_async(reservation.id, 'start')
    end
  end

  context 'updating' do
    describe '#update_reservation' do
      it 'should tell the server to update the reservation' do
        Server.any_instance.should_receive(:update_reservation).with(reservation)
        ReservationWorker.perform_async(reservation.id, 'update')
      end
    end
  end

  context 'ending' do
    let(:reservation) { create :reservation }

    it 'should send the end_reservation message to the server' do
      Server.any_instance.should_receive(:end_reservation)
      ReservationWorker.perform_async(reservation.id, 'end')
    end

    it 'should enqueue ReservationCleanupWorker after ending reservation for async cleanup servers' do
      temp_directory = "/tmp/reservation-#{reservation.id}"
      allow_any_instance_of(Server).to receive(:end_reservation)
      allow_any_instance_of(Server).to receive(:uses_async_cleanup?).and_return(true)
      allow_any_instance_of(Server).to receive(:temp_directory_for_reservation).and_return(temp_directory)

      expect(ReservationCleanupWorker).to receive(:perform_async).with(reservation.id, temp_directory)

      ReservationWorker.new.perform(reservation.id, 'end')
    end

    it 'should not enqueue ReservationCleanupWorker for FTP-based RemoteServers' do
      allow_any_instance_of(LocalServer).to receive(:end_reservation)
      expect_any_instance_of(LocalServer).to receive(:uses_async_cleanup?).and_return(false)

      expect(ReservationCleanupWorker).not_to receive(:perform_async)

      ReservationWorker.new.perform(reservation.id, 'end')
    end
  end
end
