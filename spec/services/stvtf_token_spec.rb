# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe StvtfToken do
  let(:key) { '11' * 32 }

  around do |example|
    old = ENV.to_h.slice('STVTF_URL', 'STVTF_TOKEN_KEY')
    ENV['STVTF_URL'] = 'https://stv.tf/'
    ENV['STVTF_TOKEN_KEY'] = key
    example.run
  ensure
    %w[STVTF_URL STVTF_TOKEN_KEY].each { |k| old.key?(k) ? ENV[k] = old[k] : ENV.delete(k) }
  end

  # The map server's side: decrypt and check the tag.
  let(:open) do
    lambda do |token|
      raw = Base64.urlsafe_decode64(token + ('=' * ((4 - (token.length % 4)) % 4)))
      cipher = OpenSSL::Cipher.new('aes-256-gcm').decrypt
      cipher.key = [ key ].pack('H*')
      cipher.iv = raw[0, 12]
      cipher.auth_tag = raw[-16..]
      cipher.auth_data = ''
      JSON.parse(cipher.update(raw[12...-16]) + cipher.final)
    end
  end

  it 'encrypts the connect string, owner and expiry for the map server' do
    now = Time.zone.at(1_000_000)
    payload = open.call(described_class.generate(connect: 'connect 1.2.3.4:27020; password "tv"', owner: '765', now: now))
    expect(payload).to eq('connect' => 'connect 1.2.3.4:27020; password "tv"', 'owner' => '765', 'exp' => 1_000_060)
  end

  it 'can carry a demos.tf demo instead of a connect string' do
    now = Time.zone.at(1_000_000)
    payload = open.call(described_class.generate(demo: 1_527_264, owner: nil, now: now))
    expect(payload).to eq('demo' => 1_527_264, 'owner' => nil, 'exp' => 1_000_060)
    expect { described_class.generate(connect: 'x', demo: 1, owner: nil) }.to raise_error(ArgumentError)
    expect { described_class.generate(owner: nil) }.to raise_error(ArgumentError)
  end

  it 'keeps the password out of the readable URL' do
    url = described_class.start_url(connect: 'connect 1.2.3.4:27020; password "hunter2"', owner: nil)
    expect(url).to start_with('https://stv.tf/start?t=')
    expect(url).not_to include('hunter2')
    expect(open.call(url.split('t=').last)['owner']).to be_nil
  end

  it 'uses a fresh nonce every time' do
    a = described_class.generate(connect: 'x', owner: nil)
    b = described_class.generate(connect: 'x', owner: nil)
    expect(a).not_to eq(b)
  end

  it 'is disabled without a URL or key' do
    expect(described_class).to be_enabled
    ENV.delete('STVTF_TOKEN_KEY')
    expect(described_class).not_to be_enabled
  end
end
