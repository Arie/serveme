# typed: false
# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

describe DemostfDemo do
  around { |example| VCR.turned_off { example.run } }

  it 'reads the ways people paste a demos.tf link' do
    [ 'https://demos.tf/1527264', ' http://demos.tf/1527264/ ', 'demos.tf/1527264', 'https://www.demos.tf/1527264',
      'https://demos.tf/1527264#123', 'HTTPS://DEMOS.TF/1527264' ].each do |link|
      expect(described_class.parse(link)&.id).to eq(1_527_264), link
    end
  end

  it 'leaves everything else to the connect string' do
    [ '', '1.2.3.4:27020 tv', 'https://demos.tf/', 'https://demos.tf/profiles/76561197960497430', 'https://evil.tf/demos.tf/1',
      'https://static.demos.tf/0e/c0/x.dem', 'https://demos.tf/1527264 tv', 'https://notdemos.tf/1' ].each do |input|
      expect(described_class.parse(input)).to be_nil, input
    end
  end

  it 'checks that demos.tf has the demo' do
    stub_request(:get, 'https://api.demos.tf/demos/1527264').to_return(status: 200, body: '{"id":1527264}')
    expect(described_class.new(1_527_264).check!.id).to eq(1_527_264)
  end

  it 'says when demos.tf has no such demo, or does not answer' do
    stub_request(:get, 'https://api.demos.tf/demos/1').to_return(status: 404, body: 'requested demo not found')
    expect { described_class.new(1).check! }.to raise_error(DemostfDemo::Error, 'demos.tf has no demo 1')
    stub_request(:get, 'https://api.demos.tf/demos/2').to_return(status: 502)
    expect { described_class.new(2).check! }.to raise_error(DemostfDemo::Error, /did not answer/)
    stub_request(:get, 'https://api.demos.tf/demos/3').to_timeout
    expect { described_class.new(3).check! }.to raise_error(DemostfDemo::Error, /did not answer/)
  end
end
