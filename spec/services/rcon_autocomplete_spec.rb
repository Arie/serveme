# frozen_string_literal: true

require 'spec_helper'

describe RconAutocomplete do
  subject { described_class.new(nil) }

  it 'returns a list of suggestions' do
    expect(subject.autocomplete('tf_bot').map { |c| c[:command] }).to start_with %w[
      tf_bot_add
      tf_bot_difficulty
      tf_bot_kick
    ]
  end

  it 'limits auto completion to 5 suggestions' do
    expect(subject.autocomplete('tf_').length).to be(5)
  end

  it 'completes changelevel further' do
    expect(subject.autocomplete('changelevel cp_r').map { |c| c[:command] }).to start_with ['changelevel cp_reckoner']
  end

  it 'completes exec further' do
    expect(subject.autocomplete('exec etf').map { |c| c[:command] }).to start_with ['exec etf2l', 'exec etf2l_6v6']
  end

  it 'completes mp_tournament_whitelist further' do
    expect(subject.autocomplete('mp_tournament_whitelist etf2l_whitelist_6').map { |c| c[:command] }).to start_with ['mp_tournament_whitelist etf2l_whitelist_6v6.txt']
  end

  it 'completes tftrue_whitelist_id further' do
    expect(subject.autocomplete('tftrue_whitelist_id etf').map { |c| c[:command] }).to start_with ['tftrue_whitelist_id etf2l_whitelist_6v6']
  end

  it 'completes kick command with current players' do
    reservation = create(:reservation)
    reservation_player = create(:reservation_player, reservation_id: reservation.id, name: 'Arie - serveme.tf', steam_uid: '76561197960497430')
    _player_statistic = create(:player_statistic, reservation_player_id: reservation_player.id)
    completer = described_class.new(reservation)
    expect(completer.autocomplete('kick Ar')).to eql [
      {
        command: 'kickid "[U:1:231702]"',
        description: 'Kick Arie - serveme.tf',
        display_text: 'kick "Arie - serveme.tf"'
      }

    ]
  end

  it 'doesnt try to complete different commands' do
    expect { subject.autocomplete('kick_bot al') }.not_to raise_error
  end

  it 'completes ban command with current players' do
    reservation = create(:reservation)
    reservation_player = create(:reservation_player, reservation_id: reservation.id, name: 'Arie - serveme.tf', steam_uid: '76561197960497430')
    _player_statistic = create(:player_statistic, reservation_player_id: reservation_player.id)
    completer = described_class.new(reservation)
    expect(completer.autocomplete('ban Ar')).to eql [
      {
        command: 'banid 0 [U:1:231702] kick',
        description: 'Ban Arie - serveme.tf',
        display_text: 'ban "Arie - serveme.tf"'
      }
    ]
  end
end
