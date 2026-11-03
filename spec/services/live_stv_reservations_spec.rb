# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe LiveStvReservations do
  before { Rails.cache.clear }

  it 'lists running reservations with their latest map and current players, the fullest first' do
    quiet = create(:reservation, starts_at: 10.minutes.ago, ends_at: 1.hour.from_now)
    busy = create(:reservation, starts_at: 5.minutes.ago, ends_at: 1.hour.from_now)
    create(:reservation, starts_at: 2.hours.from_now, ends_at: 3.hours.from_now)
    create(:server_statistic, reservation: busy, server: busy.server, map_name: 'cp_process_f12', created_at: 2.minutes.ago)
    create(:server_statistic, reservation: busy, server: busy.server, map_name: 'koth_product_final', created_at: 1.minute.ago)
    create(:player_statistic, reservation_player: create(:reservation_player, reservation: busy, name: 'moss', steam_uid: '76561197960497430'))

    rows = described_class.rows
    expect(rows.map(&:reservation)).to eq([ busy, quiet ])
    expect(rows.first.map).to eq('koth_product_final')
    expect(rows.first.players.map(&:name)).to eq([ 'moss' ])
    expect(rows.last.players).to be_empty
  end

  it 'leaves out reservations on SDR servers' do
    reservation = create(:reservation, starts_at: 5.minutes.ago, ends_at: 1.hour.from_now)
    allow_any_instance_of(Reservation).to receive(:stv_watchable?).and_return(false)
    expect(described_class.rows.map(&:reservation)).not_to include(reservation)
  end
end
