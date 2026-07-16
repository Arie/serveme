# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe ReservationManager do
  describe '#end_reservation' do
    it 'only fires the terminal end step once when two triggers race through the guard' do
      reservation = create(:reservation)

      # Two independent triggers (e.g. CronWorker#end_past_reservations and
      # ActiveReservationsCheckerWorker) each load their own copy of the
      # reservation and race through the guard.
      first_trigger  = Reservation.find(reservation.id)
      second_trigger = Reservation.find(reservation.id)

      # Simulate the race: the second trigger evaluated the guard with a stale
      # view (before the first trigger persisted its "Ending" status), so its
      # non-atomic check-then-act passes even though the first trigger is
      # already ending the reservation.
      allow(second_trigger).to receive(:status).and_return('Unknown')

      expect(ReservationWorker).to receive(:perform_async).with(reservation.id, 'end').once

      ReservationManager.new(first_trigger).end_reservation
      ReservationManager.new(second_trigger).end_reservation
    end
  end
end
