# frozen_string_literal: true

require 'spec_helper'

describe SimraiServer do
  describe '#restart' do
    it 'logs an error if it failed', :vcr do
      subject.stub(billing_id: 'serveme_1')

      allow(Rails.logger).to receive(:error)
      subject.restart

      expect(Rails.logger).to have_received(:error).with(/TCAdmin responded/)
    end

    it 'logs success when it succeeded', :vcr do
      subject.stub(billing_id: 'serveme_1')

      allow(Rails.logger).to receive(:info)
      subject.restart

      expect(Rails.logger).to have_received(:info).with(/Simrai restart response/)
    end
  end

  describe '#tv_port' do
    it 'is always +1 from gameserver port' do
      subject.port = 10
      expect(subject.tv_port).to eql 11
    end
  end
end
