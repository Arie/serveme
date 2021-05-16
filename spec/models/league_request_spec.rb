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

    it 'cross references players by IP' do
      player = create(:reservation_player, steam_uid: 'abc', ip: '8.8.8.8')
      alt = create(:reservation_player, steam_uid: 'def', ip: '8.8.8.8')
      other_ip = create(:reservation_player, steam_uid: 'abc', ip: '1.1.1.1')
      _other_player = create(:reservation_player, steam_uid: 'ghj', ip: '4.4.2.2')

      request = LeagueRequest.new(user, ip: '8.8.8.8', cross_reference: '1')
      results = request.search

      expect(results.size).to eql(3)
      expect(results.map(&:id).sort).to eql([player.id, alt.id, other_ip.id])
    end

    it 'cross references players by steam uid' do
      player = create(:reservation_player, steam_uid: 'abc', ip: '8.8.8.8')
      alt = create(:reservation_player, steam_uid: 'def', ip: '8.8.8.8')
      other_ip = create(:reservation_player, steam_uid: 'abc', ip: '1.1.1.1')
      _other_player = create(:reservation_player, steam_uid: 'ghj', ip: '4.4.2.2')

      request = LeagueRequest.new(user, steam_uid: 'abc', cross_reference: '1')
      results = request.search

      expect(results.size).to eql(3)
      expect(results.map(&:id).sort).to eql([player.id, alt.id, other_ip.id])
    end
  end
end
