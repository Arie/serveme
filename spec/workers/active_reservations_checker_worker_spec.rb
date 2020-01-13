# frozen_string_literal: true

require 'spec_helper'

describe ActiveReservationsCheckerWorker do
  it 'starts all the reservation checkers' do
    reservation = create(:reservation)
    reservation_ids = [reservation.id]

    ActiveReservationCheckerWorker.should_receive(:perform_async).with(reservation.id)

    ActiveReservationsCheckerWorker.perform_async(reservation_ids)
  end
end
