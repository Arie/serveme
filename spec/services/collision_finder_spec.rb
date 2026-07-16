# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe CollisionFinder do
  # Base existing reservation X spans [T, T + 1h]. Times are set with
  # update_columns to bypass the future/past/availability validators, matching
  # the pattern used elsewhere in the suite (see the :old reservation trait).
  let(:base_time) { Time.zone.parse('2026-07-16 12:00:00') }

  define_method(:persist_reservation) do |starts_at:, ends_at:, ended: false|
    reservation = create(:reservation)
    reservation.update_columns(starts_at: starts_at, ends_at: ends_at, ended: ended)
    reservation.reload
  end

  let!(:existing) do
    persist_reservation(starts_at: base_time, ends_at: base_time + 1.hour)
  end
  let(:colliding_with) { Reservation.all }

  define_method(:collisions_for) do |starts_at:, ends_at:, **attrs|
    collider = build(:reservation, starts_at: starts_at, ends_at: ends_at, **attrs)
    described_class.new(colliding_with, collider).colliding_reservations
  end

  describe '#colliding_reservations' do
    it 'detects a front overlap (collider starts before, ends inside)' do
      result = collisions_for(starts_at: base_time - 10.minutes, ends_at: base_time + 30.minutes)
      expect(result).to eq([ existing ])
    end

    it 'detects a rear overlap (collider starts inside, ends after)' do
      result = collisions_for(starts_at: base_time + 50.minutes, ends_at: base_time + 2.hours)
      expect(result).to eq([ existing ])
    end

    it 'detects an internal collision (collider fully inside existing)' do
      result = collisions_for(starts_at: base_time + 10.minutes, ends_at: base_time + 50.minutes)
      expect(result).to eq([ existing ])
    end

    it 'detects a complete overlap (existing fully inside collider)' do
      result = collisions_for(starts_at: base_time - 10.minutes, ends_at: base_time + 2.hours)
      expect(result).to eq([ existing ])
    end

    it 'does not collide with a reservation entirely before it' do
      result = collisions_for(starts_at: base_time - 2.hours, ends_at: base_time - 1.hour)
      expect(result).to be_empty
    end

    it 'does not collide with a reservation entirely after it' do
      result = collisions_for(starts_at: base_time + 2.hours, ends_at: base_time + 3.hours)
      expect(result).to be_empty
    end

    it 'treats a boundary touch at the existing end as a collision (inclusive range)' do
      # Collider starts exactly when existing ends.
      result = collisions_for(starts_at: base_time + 1.hour, ends_at: base_time + 2.hours)
      expect(result).to eq([ existing ])
    end

    it 'treats a boundary touch at the existing start as a collision (inclusive range)' do
      # Collider ends exactly when existing starts.
      result = collisions_for(starts_at: base_time - 1.hour, ends_at: base_time)
      expect(result).to eq([ existing ])
    end

    it 'returns each colliding reservation only once even when multiple clauses match' do
      result = collisions_for(starts_at: base_time - 10.minutes, ends_at: base_time + 2.hours)
      expect(result.length).to eq(1)
    end

    it 'excludes ended reservations from internal-overlap detection' do
      existing.update_columns(ended: true)
      result = collisions_for(starts_at: base_time + 10.minutes, ends_at: base_time + 50.minutes)
      expect(result).to be_empty
    end

    it 'does not report a persisted collider as colliding with itself' do
      finder = described_class.new(Reservation.all, existing)
      expect(finder.colliding_reservations).to be_empty
    end

    it 'still reports overlaps with other reservations while excluding self' do
      other = persist_reservation(starts_at: base_time + 30.minutes, ends_at: base_time + 90.minutes)
      finder = described_class.new(Reservation.all, other)
      expect(finder.colliding_reservations).to eq([ existing ])
    end
  end
end
