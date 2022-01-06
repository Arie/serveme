# frozen_string_literal: true

require 'spec_helper'

describe RconAutocomplete do
  subject { described_class.new(nil) }

  it 'returns a list of suggestions' do
    expect(subject.autocomplete('ban')).to start_with %w[banid banip]
    expect(subject.autocomplete('tf_bot')).to start_with %w[tf_bot_add tf_bot_difficulty tf_bot_kick tf_bot_kill]
  end

  it 'limits auto completion to 5 suggestions' do
    expect(subject.autocomplete('tf_').length).to be(5)
  end

  it 'completes changelevel further' do
    expect(subject.autocomplete('changelevel cp_r')).to start_with ['changelevel cp_reckoner_rc6']
  end

  it 'completes exec further' do
    expect(subject.autocomplete('exec etf')).to start_with ['exec etf2l', 'exec etf2l_6v6']
  end
end
