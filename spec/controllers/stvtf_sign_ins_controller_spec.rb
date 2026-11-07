# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe StvtfSignInsController do
  let(:key) { '33' * 32 }

  around do |example|
    old = ENV.to_h.slice('STVTF_URL', 'STVTF_TOKEN_KEY')
    ENV['STVTF_URL'] = 'https://stv.tf'
    ENV['STVTF_TOKEN_KEY'] = key
    example.run
  ensure
    %w[STVTF_URL STVTF_TOKEN_KEY].each { |k| old.key?(k) ? ENV[k] = old[k] : ENV.delete(k) }
  end

  # The map server's side: the token's claims, and where it goes back to.
  let(:back) do
    lambda do |location|
    uri = URI.parse(location)
    query = Rack::Utils.parse_query(uri.query)
    raw = Base64.urlsafe_decode64(query['t'] + ('=' * ((4 - (query['t'].length % 4)) % 4)))
    cipher = OpenSSL::Cipher.new('aes-256-gcm').decrypt
    cipher.key = [ key ].pack('H*')
    cipher.iv = raw[0, 12]
    cipher.auth_tag = raw[-16..]
    cipher.auth_data = ''
    [ "#{uri.scheme}://#{uri.host}#{uri.path}", JSON.parse(cipher.update(raw[12...-16]) + cipher.final), query['return'] ]
    end
  end

  let(:user) { create(:user, nickname: 'Arie') }

  it 'sends a user back to the room signed in, by Steam uid and name' do
    sign_in user
    get :show, params: { return: '/r/abc/' }
    url, claims, path = back.call(response.location)
    expect(url).to eq('https://stv.tf/signed_in')
    expect(claims['signin']).to eq('uid' => user.uid, 'name' => 'Arie', 'streamer' => false)
    expect(path).to eq('/r/abc/')
  end

  it 'says a streamer is one' do
    user.groups << Group.streamer_group
    sign_in user
    get :show, params: { return: '/r/abc/' }
    expect(back.call(response.location)[1]['signin']['streamer']).to be(true)
  end

  it 'goes back only to a page of the map server' do
    sign_in user
    [ 'https://evil.example/', '//evil.example/', '/\\evil.example' ].each do |elsewhere|
      get :show, params: { return: elsewhere }
      expect(back.call(response.location)[2]).to eq('/')
    end
  end

  it 'has the user sign in here first' do
    get :show, params: { return: '/r/abc/' }
    expect(response.location).not_to start_with('https://stv.tf')
    expect(session[:user_return_to]).to include('/stv/sign_in')
  end
end
