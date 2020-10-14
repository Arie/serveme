# frozen_string_literal: true

require 'spec_helper'

describe NfoServer do
  describe '#demos' do
    it 'lists all the files and filters the demos' do
      subject.should_receive(:list_files).with('') { ['foo.vpk', 'bar.dem', 'gameinfo.txt', 'foo.dem'] }
      subject.demos.should == ['/tf/bar.dem', '/tf/foo.dem']
    end
  end
end
