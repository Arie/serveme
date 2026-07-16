# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe ReservationManager do
  describe '#end_reservation' do
    it 'only fires the terminal end step once when two triggers race through the guard' do
      reservation = create(:reservation)

      # Two independent triggers (e.g. CronWorker#end_past_reservations and
      # ActiveReservationsCheckerWorker) each load their own copy of the
      # reservation and race to claim the transition.
      first_trigger  = Reservation.find(reservation.id)
      second_trigger = Reservation.find(reservation.id)

      expect(ReservationWorker).to receive(:perform_async).with(reservation.id, 'end').once

      ReservationManager.new(first_trigger).end_reservation
      ReservationManager.new(second_trigger).end_reservation
    end

    it 'allows a re-claim once a stale claim passes the TTL, so a dead end job self-heals' do
      reservation = create(:reservation)

      # A previous end trigger claimed the transition but its worker died
      # without ever setting ended: true.
      stale = reservation.reservation_statuses.create!(status: 'Ending')
      stale.update_column(:created_at, (ReservationManager::CLAIM_TTL + 1.minute).ago)

      expect(ReservationWorker).to receive(:perform_async).with(reservation.id, 'end').once

      ReservationManager.new(reservation).end_reservation
    end

    it 'does not re-claim while a recent claim is still live' do
      reservation = create(:reservation)
      reservation.reservation_statuses.create!(status: 'Ending')

      expect(ReservationWorker).not_to receive(:perform_async)

      ReservationManager.new(reservation).end_reservation
    end

    it 'does nothing for an already ended reservation' do
      reservation = create(:reservation)
      reservation.update_columns(ended: true)

      expect(ReservationWorker).not_to receive(:perform_async)

      ReservationManager.new(reservation).end_reservation
    end
  end

  describe '#start_reservation' do
    it 'only fires the start worker once when two triggers race through the guard' do
      reservation = create(:reservation)

      first_trigger  = Reservation.find(reservation.id)
      second_trigger = Reservation.find(reservation.id)

      expect(ReservationWorker).to receive(:perform_async).with(reservation.id, 'start').once

      ReservationManager.new(first_trigger).start_reservation
      ReservationManager.new(second_trigger).start_reservation
    end

    it 'allows a re-claim once a stale claim passes the TTL, so a dead start job self-heals' do
      reservation = create(:reservation)

      stale = reservation.reservation_statuses.create!(status: 'Starting')
      stale.update_column(:created_at, (ReservationManager::CLAIM_TTL + 1.minute).ago)

      expect(ReservationWorker).to receive(:perform_async).with(reservation.id, 'start').once

      ReservationManager.new(reservation).start_reservation
    end

    it 'does not fire again once the reservation is provisioned' do
      reservation = create(:reservation, provisioned: true)

      expect(ReservationWorker).not_to receive(:perform_async)

      ReservationManager.new(reservation).start_reservation
    end
  end
end
