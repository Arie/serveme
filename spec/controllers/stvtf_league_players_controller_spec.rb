# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe StvtfLeaguePlayersController do
  let(:key) { '33' * 32 }

  around do |example|
    old = ENV.to_h.slice('STVTF_URL', 'STVTF_TOKEN_KEY')
    ENV['STVTF_URL'] = 'https://stv.tf'
    ENV['STVTF_TOKEN_KEY'] = key
    example.run
  ensure
    %w[STVTF_URL STVTF_TOKEN_KEY].each { |k| old.key?(k) ? ENV[k] = old[k] : ENV.delete(k) }
  end

  # The map server's side: a token sealed with the key the two share.
  let(:sealed) do
    lambda do |claims, with = key|
      cipher = OpenSSL::Cipher.new('aes-256-gcm').encrypt
      cipher.key = [ with ].pack('H*')
      nonce = cipher.random_iv
      cipher.auth_data = ''
      Base64.urlsafe_encode64(nonce + cipher.update(claims.to_json) + cipher.final + cipher.auth_tag, padding: false)
    end
  end

  let(:token) { sealed.call({ league: true, exp: 1.minute.from_now.to_i }) }
  let(:one) { '76561198000000001' }
  let(:two) { '76561198000000002' }

  let(:asked) do
    lambda do |with, uids|
      request.headers['Authorization'] = "Bearer #{with}"
      get :index, params: { steam_uids: uids }
    end
  end

  it "tells ETF2L's names and teams on the European site, leaving out who it does not know" do
    stub_const('SITE_HOST', 'serveme.tf')
    teams = [ { 'name' => 'Team A', 'tag' => 'A', 'type' => '6v6' }, { 'name' => 'Nine', 'tag' => '9', 'type' => 'Highlander' } ]
    allow(Etf2lApi).to receive(:profile).with(one).and_return({ player: { name: 'One', teams: teams } }.to_json)
    allow(Etf2lApi).to receive(:profile).with(two).and_return('{"status":{"code":404}}')
    asked.call(token, "#{two},#{one},nonsense,#{one}")
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq(
      'league' => 'ETF2L',
      'players' => [ { 'steam_uid' => one, 'name' => 'One', 'teams' => [
        { 'name' => 'Team A', 'tag' => 'A', 'format' => '6v6' }, { 'name' => 'Nine', 'tag' => '9', 'format' => 'Highlander' }
      ] } ]
    )
  end

  it "tells RGL's on the North American site: a team for each format they play" do
    stub_const('SITE_HOST', 'na.serveme.tf')
    current = { sixes: { name: 'Six', tag: 'SIX' }, highlander: nil }
    allow(RglApi).to receive(:profile).with(one).and_return({ name: 'One', currentTeams: current }.to_json)
    asked.call(token, one)
    expect(response.parsed_body).to eq(
      'league' => 'RGL',
      'players' => [ { 'steam_uid' => one, 'name' => 'One', 'teams' => [ { 'name' => 'Six', 'tag' => 'SIX', 'format' => 'sixes' } ] } ]
    )
  end

  it "tells ozfortress's on the Australian site: the rosters still together" do
    stub_const('SITE_HOST', 'au.serveme.tf')
    rosters = [ { name: 'Old', disbanded: true }, { name: 'Now', disbanded: false } ]
    allow(OzfortressApi).to receive(:profile).with(one).and_return({ user: { name: 'One', rosters: rosters } }.to_json)
    asked.call(token, one)
    expect(response.parsed_body['league']).to eq('ozfortress')
    expect(response.parsed_body['players'].first['teams']).to eq([ { 'name' => 'Now', 'tag' => nil, 'format' => nil } ])
  end

  it 'knows nobody where there is no league, or the league does not answer' do
    stub_const('SITE_HOST', 'sea.serveme.tf')
    asked.call(token, one)
    expect(response.parsed_body).to eq('league' => nil, 'players' => [])
    stub_const('SITE_HOST', 'serveme.tf')
    allow(Etf2lApi).to receive(:profile).and_raise(Faraday::TimeoutError)
    asked.call(token, one)
    expect(response.parsed_body).to eq('league' => 'ETF2L', 'players' => [])
  end

  it 'tells nobody else' do
    stub_const('SITE_HOST', 'serveme.tf')
    expect(Etf2lApi).not_to receive(:profile)
    [
      nil,
      'nonsense',
      sealed.call({ league: true, exp: 1.minute.ago.to_i }),
      sealed.call({ list: true, exp: 1.minute.from_now.to_i }),
      sealed.call({ link: one, exp: 1.minute.from_now.to_i }),
      sealed.call({ league: true, exp: 1.minute.from_now.to_i }, '44' * 32)
    ].each do |other|
      asked.call(other, one)
      expect(response).to have_http_status(:forbidden)
    end
  end

  it 'is not there without the map server' do
    ENV.delete('STVTF_TOKEN_KEY')
    asked.call(token, one)
    expect(response).to have_http_status(:not_found)
  end
end
