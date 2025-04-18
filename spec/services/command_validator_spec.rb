# typed: false

require 'spec_helper'

describe CommandValidator do
  describe '.validate' do
    context 'with single commands' do
      it 'returns true for a likely valid command (changelevel)' do
        expect(described_class.validate('changelevel cp_process')).to be true
      end

      it 'returns true for a likely valid command (mp_timelimit)' do
        expect(described_class.validate('mp_timelimit 60')).to be true
      end

      it 'returns false for a clearly invalid command' do
        expect(Rails.logger).to receive(:warn).with(/Disallowed command 'xyz_invalid_command_abc'/)
        expect(described_class.validate('xyz_invalid_command_abc please')).to be false
      end

      it 'returns true for likely valid command _restart' do
        expect(described_class.validate('_restart')).to be true
      end

      it 'returns true for likely valid command exec' do
        expect(described_class.validate('exec myconfig')).to be true
      end

      it 'returns true for likely valid command say' do
        expect(described_class.validate('say hello')).to be true
      end
    end

    context 'with multiple commands' do
      it 'returns true for multiple likely valid commands' do
        expect(described_class.validate('mp_timelimit 60; changelevel cp_process; say hello')).to be true
      end

      it 'returns false if any command is invalid' do
        expect(Rails.logger).to receive(:warn).with(/Disallowed command 'xyz_invalid_command_abc'/)
        expect(described_class.validate('mp_timelimit 60; xyz_invalid_command_abc; changelevel cp_process')).to be false
      end

      it 'handles extra spacing and semicolons' do
        expect(described_class.validate('  mp_timelimit 60 ;; changelevel cp_process ; ')).to be true
      end
    end

    context 'with edge cases' do
      it 'returns true for an empty string' do
        expect(described_class.validate('')).to be true
      end

      it 'returns true for a nil command' do
        expect(described_class.validate(nil)).to be true
      end
    end
  end
end
