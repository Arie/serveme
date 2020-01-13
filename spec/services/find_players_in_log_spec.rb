# frozen_string_literal: true

require 'spec_helper'

describe FindPlayersInLog do
  describe '.perform' do
    it 'takes a log and finds the players in it' do
      log = Rails.root.join('spec', 'fixtures', 'logs', 'special_characters.log')
      FindPlayersInLog.perform(log).should == [76_561_197_970_773_724, 76_561_198_012_531_702, 76_561_198_043_711_148, 76_561_197_979_088_829, 76_561_198_012_531_702, 76_561_198_054_664_886, 76_561_198_012_531_702, 76_561_197_978_390_640, 76_561_198_030_042_478, 76_561_197_986_034_945, 76_561_197_991_320_838, 76_561_197_991_033_579, 76_561_197_993_843_145, 76_561_197_994_754_935, 76_561_198_030_042_478]
    end
  end
end
