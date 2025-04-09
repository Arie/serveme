# typed: false

require 'spec_helper'
require 'webmock/rspec'

RSpec.describe RglApi do
  let(:steam_uid) { '76561198012598620' }
  let(:profile_response) { { name: 'Test Player' }.to_json }

  describe '.profile' do
    context 'when response is cached' do
      before do
        Rails.cache.write("rgl_profile_#{steam_uid}", profile_response)
      end

      after do
        Rails.cache.delete("rgl_profile_#{steam_uid}")
      end

      it 'returns cached response' do
        expect(described_class).not_to receive(:fetch_profile)
        expect(described_class.profile(steam_uid)).to eq(profile_response)
      end
    end

    context 'when response is not cached' do
      before do
        Rails.cache.delete("rgl_profile_#{steam_uid}")
      end

      it 'fetches and caches the response' do
        VCR.use_cassette('rgl_api/profile_success') do
          stub_request(:get, "https://api.rgl.gg/v0/profile/#{steam_uid}")
            .to_return(status: 200, body: profile_response)

          expect(described_class.profile(steam_uid)).to eq(profile_response)
          expect(Rails.cache.read("rgl_profile_#{steam_uid}")).to eq(profile_response)
        end
      end

      it 'handles 404 responses' do
        VCR.use_cassette('rgl_api/profile_404') do
          stub_request(:get, "https://api.rgl.gg/v0/profile/#{steam_uid}")
            .to_return(status: 404, body: '')

          expect(described_class.profile(steam_uid)).to eq('')
          expect(Rails.cache.read("rgl_profile_#{steam_uid}")).to eq('')
        end
      end

      it 'returns nil for failed requests' do
        VCR.use_cassette('rgl_api/profile_error') do
          stub_request(:get, "https://api.rgl.gg/v0/profile/#{steam_uid}")
            .to_return(status: 500, body: 'Error')

          expect(described_class.profile(steam_uid)).to be_nil
          expect(Rails.cache.read("rgl_profile_#{steam_uid}")).to be_nil
        end
      end

      it 'returns nil for timeout errors' do
        VCR.use_cassette('rgl_api/profile_timeout') do
          stub_request(:get, "https://api.rgl.gg/v0/profile/#{steam_uid}")
            .to_timeout

          expect(described_class.profile(steam_uid)).to be_nil
          expect(Rails.cache.read("rgl_profile_#{steam_uid}")).to be_nil
        end
      end
    end
  end

  describe '.rgl_connection' do
    subject(:connection) { described_class.rgl_connection }

    it 'configures Faraday with correct options' do
      expect(connection.url_prefix.to_s).to eq('https://api.rgl.gg/')
      expect(connection.options.timeout).to eq(5)
      expect(connection.options.open_timeout).to eq(5)
    end
  end
end
