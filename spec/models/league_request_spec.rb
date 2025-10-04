# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe LeagueRequest do
  let(:user) { create(:user, name: 'Admin') }

  describe '#search' do
    it 'finds players by steam uid' do
      player = create(:reservation_player, steam_uid: 'abc')
      create(:reservation_player, steam_uid: 'def')

      request = LeagueRequest.new(user, steam_uid: 'abc')
      results = request.search

      expect(results.size).to eql(1)
      expect(results.first.id).to eql(player.id)
    end

    it 'finds players by IP' do
      player = create(:reservation_player, ip: '8.8.8.8')
      create(:reservation_player, ip: '1.1.1.1')

      request = LeagueRequest.new(user, ip: '8.8.8.8')
      results = request.search

      expect(results.size).to eql(1)
      expect(results.first.id).to eql(player.id)
    end

    it 'ignores games played on SDR servers' do
      sdr_server = create(:server, sdr: true)
      reservation = create(:reservation, server: sdr_server)
      create(:reservation_player, reservation: reservation, ip: '8.8.8.8')

      request = LeagueRequest.new(user, ip: '8.8.8.8')
      results = request.search

      expect(results.size).to eql(0)
    end

    it 'cross references players by IP' do
      player = create(:reservation_player, steam_uid: 'abc', ip: '8.8.8.8')
      alt = create(:reservation_player, steam_uid: 'def', ip: '8.8.8.8')
      other_ip = create(:reservation_player, steam_uid: 'abc', ip: '1.1.1.1')
      _other_player = create(:reservation_player, steam_uid: 'ghj', ip: '4.4.2.2')

      request = LeagueRequest.new(user, ip: '8.8.8.8', cross_reference: '1')
      results = request.search

      expect(results.size).to eql(3)
      expect(results.map(&:id).sort).to eql([ player.id, alt.id, other_ip.id ])
    end

    it 'cross references players by steam uid' do
      player = create(:reservation_player, steam_uid: 'abc', ip: '8.8.8.8')
      alt = create(:reservation_player, steam_uid: 'def', ip: '8.8.8.8')
      other_ip = create(:reservation_player, steam_uid: 'abc', ip: '1.1.1.1')
      _other_player = create(:reservation_player, steam_uid: 'ghj', ip: '4.4.2.2')

      request = LeagueRequest.new(user, steam_uid: 'abc', cross_reference: '1')
      results = request.search

      expect(results.size).to eql(3)
      expect(results.map(&:id).sort).to eql([ player.id, alt.id, other_ip.id ])
    end

    it 'can filter by reservation_ids' do
      reservation = create :reservation
      other_reservation = create :reservation
      filtered_reservation = create :reservation

      player = create(:reservation_player, steam_uid: 'abc', ip: '8.8.8.8', reservation_id: reservation.id)
      alt = create(:reservation_player, steam_uid: 'def', ip: '8.8.8.8', reservation_id: reservation.id)
      alt_other_reservation = create(:reservation_player, steam_uid: 'def', ip: '8.8.8.8', reservation_id: other_reservation.id)
      _alt_filtered_reservation = create(:reservation_player, steam_uid: 'def', ip: '8.8.8.8', reservation_id: filtered_reservation.id)
      other_ip = create(:reservation_player, steam_uid: 'abc', ip: '1.1.1.1', reservation_id: reservation.id)
      _other_player = create(:reservation_player, steam_uid: 'ghj', ip: '4.4.2.2', reservation_id: reservation.id)

      request = LeagueRequest.new(user, steam_uid: 'abc', reservation_ids: [ reservation.id, other_reservation.id ], cross_reference: '1')
      results = request.search

      expect(results.size).to eql(4)
      expect(results.map(&:id).sort).to eql([ player.id, alt.id, alt_other_reservation.id, other_ip.id ])
    end
  end

  describe 'lenient input parsing' do
    it 'extracts IPs from messy text' do
      player1 = create(:reservation_player, ip: '192.168.1.1')
      player2 = create(:reservation_player, ip: '10.0.0.1')

      results = LeagueRequest.new(user, ip: '  Check: 192.168.1.1 and 10.0.0.1  ').search

      expect(results.map(&:id).sort).to eq([ player1.id, player2.id ])
    end

    it 'handles IP with spaces' do
      player = create(:reservation_player, ip: '8.8.8.8')

      results = LeagueRequest.new(user, ip: '   8.8.8.8   ').search

      expect(results.first.id).to eq(player.id)
    end

    it 'extracts Steam ID64s from text' do
      player1 = create(:reservation_player, steam_uid: '76561198123456789')
      player2 = create(:reservation_player, steam_uid: '76561198987654321')

      results = LeagueRequest.new(user, steam_uid: 'User1: 76561198123456789 User2: 76561198987654321').search

      expect(results.map(&:id).sort).to eq([ player1.id, player2.id ])
    end

    it 'handles Steam ID with spaces' do
      player = create(:reservation_player, steam_uid: '76561198123456789')

      results = LeagueRequest.new(user, steam_uid: '   76561198123456789   ').search

      expect(results.first.id).to eq(player.id)
    end

    it 'falls back for invalid formats' do
      player = create(:reservation_player, steam_uid: 'abc')

      results = LeagueRequest.new(user, steam_uid: 'abc').search

      expect(results.first.steam_uid).to eq('abc')
    end
  end

  describe 'Steam ID format conversion' do
    it 'converts Steam ID3 format (with or without brackets)' do
      # [U:1:1406945480] or U:1:1406945480 -> 76561199367211208
      player = create(:reservation_player, steam_uid: '76561199367211208')

      results1 = LeagueRequest.new(user, steam_uid: '[U:1:1406945480]').search
      results2 = LeagueRequest.new(user, steam_uid: 'U:1:1406945480').search

      expect(results1.first.id).to eq(player.id)
      expect(results2.first.id).to eq(player.id)
    end

    it 'converts classic Steam ID format' do
      # STEAM_0:0:703472740 -> 76561199367211208
      player = create(:reservation_player, steam_uid: '76561199367211208')

      results = LeagueRequest.new(user, steam_uid: 'STEAM_0:0:703472740').search

      expect(results.first.id).to eq(player.id)
    end

    it 'extracts multiple Steam ID formats from text' do
      player1 = create(:reservation_player, steam_uid: '76561199367211208')
      player2 = create(:reservation_player, steam_uid: '76561198067211208')

      results = LeagueRequest.new(user, steam_uid: '[U:1:1406945480] STEAM_0:0:53472740').search

      expect(results.map(&:id).sort).to eq([ player1.id, player2.id ])
    end
  end
end
