# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe StvtfDiscordLinksController do
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

  let(:discord) { '123456789012345678' }

  let(:asked) do
    lambda do |token, id = discord|
      request.headers['Authorization'] = "Bearer #{token}"
      get :show, params: { discord_uid: id }
    end
  end

  it 'tells the map server the Steam uid of the one Discord user it asks about' do
    linked = create(:user, discord_uid: discord)
    create(:user, discord_uid: '999')
    asked.call(sealed.call({ link: discord, exp: 1.minute.from_now.to_i }))
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq('steam' => linked.uid)
  end

  it 'knows nobody for a Discord user not linked here' do
    asked.call(sealed.call({ link: discord, exp: 1.minute.from_now.to_i }))
    expect(response).to have_http_status(:not_found)
    expect(response.body).to be_blank
  end

  it 'tells nobody else, and of nobody but the one the token is for' do
    linked = create(:user, discord_uid: discord)
    other = create(:user, discord_uid: '999')
    [
      nil,
      'nonsense',
      sealed.call({ link: discord, exp: 1.minute.ago.to_i }),
      sealed.call({ list: true, exp: 1.minute.from_now.to_i }),
      sealed.call({ links: true, exp: 1.minute.from_now.to_i }),
      sealed.call({ link: '999', exp: 1.minute.from_now.to_i }),
      sealed.call({ link: discord, exp: 1.minute.from_now.to_i }, '44' * 32)
    ].each do |token|
      asked.call(token)
      expect(response).to have_http_status(:forbidden)
      expect(response.body).not_to include(linked.uid)
      expect(response.body).not_to include(other.uid)
    end
  end

  it 'is not there without the map server' do
    token = sealed.call({ link: discord, exp: 1.minute.from_now.to_i })
    ENV.delete('STVTF_TOKEN_KEY')
    asked.call(token)
    expect(response).to have_http_status(:not_found)
  end
end
