# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe ChatCommandSuggester do
  describe '.suggest' do
    it 'suggests the closest serveme command for typos' do
      expect(described_class.suggest('!extned')).to eq '!extend'
      expect(described_class.suggest('!EXTEBD')).to eq '!extend'
      expect(described_class.suggest('!sde')).to eq '!sdr'
      expect(described_class.suggest('!whi')).to eq '!who'
    end

    it 'leaves other plugins and unrelated words alone' do
      %w[!add !rep !log !logs !rtv !remov !hogs !pause !extend hello].each do |message|
        expect(described_class.suggest(message)).to be_nil, message
      end
    end

    it 'only looks at a single command word' do
      expect(described_class.suggest('!extned please')).to be_nil
    end
  end
end
