# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe ReservationStatus do
  describe '.ordered' do
    it 'sorts by creation date' do
      reservation = create(:reservation)
      first   = create :reservation_status, reservation_id: reservation.id, created_at: 1.hour.ago
      last    = create :reservation_status, reservation_id: reservation.id, created_at: 3.hour.ago
      middle  = create :reservation_status, reservation_id: reservation.id, created_at: 2.hour.ago

      ReservationStatus.ordered.to_a.should eql [first, middle, last]
    end
  end
end
