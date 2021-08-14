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
  end
end
