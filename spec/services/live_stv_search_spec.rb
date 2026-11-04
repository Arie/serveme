# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe LiveStvSearch do
  let(:owner) { build(:user, nickname: 'Arie - serveme.tf', uid: '76561197960497430') }
  let(:reservation) { build(:reservation, user: owner) }
  let(:player) { LiveStvReservations::Player.new(name: 'moss', steam_uid: '76561198000000001', country_code: 'NL') }
  let(:row) { LiveStvReservations::Row.new(reservation: reservation, map: 'cp_process_f12', players: [ player ]) }

  it 'matches part of the owner or a player name, ignoring case' do
    expect(described_class.new('SERVEME').match?(row)).to be(true)
    expect(described_class.new('mos').match?(row)).to be(true)
    expect(described_class.new('pine').match?(row)).to be(false)
  end

  it 'matches the owner by any form of Steam ID' do
    %w[76561197960497430 STEAM_0:0:115851 [U:1:231702]].each do |id|
      expect(described_class.new(" #{id} ").match?(row)).to be(true), id
    end
  end

  it 'matches a player by SteamID64 and nothing else by it' do
    expect(described_class.new('76561198000000001').match?(row)).to be(true)
    expect(described_class.new('76561198000000002').match?(row)).to be(false)
  end

  describe '#filter' do
    let(:reservation) { create(:reservation, user: owner) }
    let(:other_row) { LiveStvReservations::Row.new(reservation: create(:reservation), map: 'cp_gullywash_f9', players: []) }

    before { create(:reservation_player, reservation: reservation, name: 'b4nny', steam_uid: '76561198000000003') }

    it 'finds players that joined but have no player statistics yet' do
      expect(described_class.new('b4nn').filter([ row, other_row ])).to eq([ row ])
      expect(described_class.new('76561198000000003').filter([ row, other_row ])).to eq([ row ])
      expect(described_class.new('nobody').filter([ row, other_row ])).to eq([])
    end
  end

  it 'is inactive when blank' do
    expect(described_class.new('  ')).not_to be_active
    expect(described_class.new(nil)).not_to be_active
  end
end
