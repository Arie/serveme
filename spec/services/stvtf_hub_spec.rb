# typed: false
# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

describe StvtfHub do
  around do |example|
    old = ENV.to_h.slice('STVTF_URL', 'STVTF_TOKEN_KEY')
    ENV['STVTF_URL'] = 'https://stv.tf'
    ENV['STVTF_TOKEN_KEY'] = '55' * 32
    VCR.turned_off { example.run }
  ensure
    %w[STVTF_URL STVTF_TOKEN_KEY].each { |k| old.key?(k) ? ENV[k] = old[k] : ENV.delete(k) }
  end

  before { Rails.cache.delete(described_class::CACHE_KEY) }

  let(:match) do
    { 'id' => 'ab' * 16, 'reservation' => 7, 'demo' => nil, 'pinned' => false, 'data_age' => 0.1, 'done' => false,
      'players' => [ { 'name' => 'moss', 'team' => 'red', 'class' => 'medic' }, { 'name' => 'pine', 'team' => 'blue', 'class' => 'scout' } ] }
  end

  it 'reads the matches with a list token' do
    stub = stub_request(:get, 'https://stv.tf/matches')
           .with { |req| req.headers['Authorization'].to_s.start_with?('Bearer ') }
           .to_return(status: 200, body: { matches: [ match ] }.to_json)
    matches, error = described_class.matches
    expect(error).to be_nil
    expect(matches.first.reservation_id).to eq(7)
    expect(matches.first.players('red').map { |p| p['name'] }).to eq([ 'moss' ])
    expect(matches.first.url).to eq("https://stv.tf/w/#{'ab' * 16}/")
    described_class.matches
    expect(stub).to have_been_requested.once
  end

  it 'says what went wrong when the hub does not answer' do
    stub_request(:get, 'https://stv.tf/matches').to_return(status: 401)
    expect(described_class.matches).to eq([ [], 'stv.tf answered 401' ])
    Rails.cache.delete(described_class::CACHE_KEY)
    stub_request(:get, 'https://stv.tf/matches').to_timeout
    matches, error = described_class.matches
    expect(matches).to be_empty
    expect(error).to be_present
  end

  it 'tells pasted matches, reservations and demos apart' do
    reserved = StvtfHub::Match.new(match)
    pasted = StvtfHub::Match.new(match.merge('reservation' => nil))
    demo = StvtfHub::Match.new(match.merge('reservation' => nil, 'demo' => 1))
    expect([ reserved.pasted?, pasted.pasted?, demo.pasted?, demo.demo? ]).to eq([ false, true, false, true ])
    expect(StvtfHub::Match.new(match.merge('data_age' => 40)).stalled?).to be(true)
    expect(reserved.stalled?).to be(false)
  end
end
