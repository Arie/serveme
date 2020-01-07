# frozen_string_literal: true

require 'spec_helper'

describe NfoControlPanel do
  subject { NfoControlPanel.new(ip: 'servechi3.tragicservers.com') }

  describe '#restart' do
    it 'submits the restart form', :vcr do
      subject.restart
    end

    it 'does not explode with a bad form' do
      form = double(:form, field_with: nil)
      page = double(:page, code: '200', form: form)
      agent = double(:agent)
      allow(agent).to receive(:get).and_return(page)
      subject.stub(agent: agent, login: nil)
      expect { subject.restart }.to_not raise_error
    end
  end
end
