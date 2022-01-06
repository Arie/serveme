# frozen_string_literal: true

require 'spec_helper'

describe RconAutocomplete do
  it 'returns a list of suggestions' do
    expect(described_class.autocomplete('ban')).to start_with %w[banid banip]
    expect(described_class.autocomplete('tf_bot')).to start_with %w[tf_bot_add tf_bot_difficulty tf_bot_kick tf_bot_kill]
  end

  it 'limits auto completion to 5 suggestions' do
    expect(described_class.autocomplete('tf_').length).to be(5)
  end

  it 'completes certain commands further' do
    expect(described_class.autocomplete('changelevel cp_r')).to start_with ['changelevel cp_reckoner_rc6']
    expect(described_class.autocomplete('exec etf')).to start_with ['exec etf2l', 'exec etf2l_6v6']
  end
end
