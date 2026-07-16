# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe ServerForReservationFinder do
  let(:user) { create(:user) }
  let(:window_start) { Time.zone.parse('2026-07-16 12:00:00') }
  let(:reservation) do
    # Built (not saved) so the far-future/availability validators don't run;
    # the finder only reads the reservation's user and time window.
    build(:reservation, user: user, server: nil, starts_at: window_start, ends_at: window_start + 2.hours)
  end

  subject { described_class.new(reservation).servers }

  # Persist a reservation on a specific server/time, bypassing the future/past
  # and availability validators the way the :old trait does.
  define_method(:book) do |server, starts_at:, ends_at:|
    reservation = create(:reservation, server: server)
    reservation.update_columns(starts_at: starts_at, ends_at: ends_at, ended: false)
    reservation
  end

  it 'returns an active, up-to-date, groupless server' do
    server = create(:server)
    expect(subject).to include(server)
  end

  it 'excludes inactive servers' do
    inactive = create(:server, active: false)
    expect(subject).not_to include(inactive)
  end

  it 'excludes outdated servers (last_known_version behind latest)' do
    outdated = create(:server, last_known_version: 1)
    expect(subject).not_to include(outdated)
  end

  it 'excludes cloud servers' do
    cloud = create(:cloud_server)
    expect(subject).not_to include(cloud)
  end

  it 'excludes a server that already has a colliding reservation in the window' do
    free = create(:server)
    booked = create(:server)
    book(booked, starts_at: window_start + 30.minutes, ends_at: window_start + 90.minutes)

    expect(subject).to include(free)
    expect(subject).not_to include(booked)
  end

  it 'keeps a server whose only reservation is outside the window' do
    server = create(:server)
    book(server, starts_at: window_start + 5.hours, ends_at: window_start + 6.hours)

    expect(subject).to include(server)
  end

  context 'group reservability' do
    let(:group) { create(:group) }
    let!(:group_server) do
      server = create(:server)
      create(:group_server, group: group, server: server)
      server
    end

    it 'excludes servers restricted to a group the user does not belong to' do
      expect(subject).not_to include(group_server)
    end

    it 'includes group-restricted servers once the user is a member of the group' do
      create(:group_user, user: user, group: group, expires_at: 1.day.from_now)

      expect(subject).to include(group_server)
    end
  end
end
