# frozen_string_literal: true

require 'spec_helper'

describe RconHelper do
  let(:host_class) { Class.new { include RconHelper } }
  let(:instance) { host_class.new }

  describe '#clean_rcon' do
    it 'replaces leading map command with changelevel' do
      expect(instance.clean_rcon('map cp_badlands')).to eql 'changelevel cp_badlands'
      expect(instance.clean_rcon('    map cp_badlands')).to eql 'changelevel cp_badlands'
    end

    it 'replaces leading rcon command with empty string' do
      expect(instance.clean_rcon('rcon say hello')).to eql 'say hello'
      expect(instance.clean_rcon('   rcon say hello')).to eql 'say hello'
    end
  end
end
