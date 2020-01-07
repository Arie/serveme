# frozen_string_literal: true

require 'spec_helper'

describe FindLogsTfUploadsInLog do
  describe '.perform' do
    it 'takes a log and finds the logs.tf uploads in it' do
      log = Rails.root.join('spec', 'fixtures', 'logs', 'special_characters.log')
      FindLogsTfUploadsInLog.perform(log).should == [1_059_884, 1_059_885, 1_059_886]
    end
  end
end
