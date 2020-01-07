# frozen_string_literal: true

require 'spec_helper'

describe Voucher do
  describe '.find_voucher' do
    it 'returns nil when a bad code is entered' do
      described_class.find_voucher("a\/13/13r 13r j13ro  ").should be_nil
    end

    it 'finds a voucher by its crockforded code' do
      voucher = create :voucher, code: '64S36D1N6RVKGE9G'

      valid_codes = ['64-S36D-1N6R-VKGE9G', '64S3-6D1N6R-VKGE9G', '6-4S36D-I-N6RVKG-E9G']

      valid_codes.each do |code|
        described_class.find_voucher(code).should eql voucher
      end
    end
  end
end
