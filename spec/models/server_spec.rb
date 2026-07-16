# typed: false
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Server do
  describe '.outdated' do
    it 'returns nothing rather than every server when the version is unknown' do
      allow(Server).to receive(:latest_version).and_return(nil)
      expect(Server.outdated).to eq(Server.none)
      expect(Server.outdated.to_sql).not_to include('1=1')
    end
  end

  describe '.fetch_latest_version' do
    before { allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production')) }

    define_method(:stub_steam) do |body|
      allow(Faraday).to receive(:new).and_return(
        instance_double(Faraday::Connection, get: instance_double(Faraday::Response, success?: true, body: body.to_json))
      )
    end

    it 'returns the required_version when Steam answers normally' do
      stub_steam("response" => { "required_version" => 10_822_003 })
      expect(Server.fetch_latest_version).to eq(10_822_003)
    end

    it 'returns nil (not 0) when required_version is missing' do
      stub_steam("response" => { "success" => false })
      expect(Server.fetch_latest_version).to be_nil
    end
  end

  describe '#save_version_info' do
    let(:server) { create(:server, update_status: 'Updating', update_started_at: Time.current) }
    let(:server_info) { double('ServerInfo') }

    before do
      allow(Server).to receive(:latest_version).and_return(100)
      allow(server_info).to receive(:version)
    end

    context 'when version is nil' do
      before { allow(server_info).to receive(:version).and_return(nil) }

      it 'returns early without updating to prevent incorrect version comparison' do
        expect(server).not_to receive(:update)
        server.save_version_info(server_info)
        expect(server.reload.update_status).to eq('Updating') # Status remains unchanged
        expect(server.last_known_version).to be_nil
      end
    end

    context 'when version is older than latest' do
      before { allow(server_info).to receive(:version).and_return(90) }

      it 'marks server as outdated' do
        server.save_version_info(server_info)
        expect(server.reload.update_status).to eq('Outdated')
        expect(server.last_known_version).to eq(90)
      end
    end

    context 'when version is equal to latest' do
      before { allow(server_info).to receive(:version).and_return(100) }

      it 'marks server as updated' do
        server.save_version_info(server_info)
        expect(server.reload.update_status).to eq('Updated')
        expect(server.last_known_version).to eq(100)
      end
    end

    context 'when version is newer than latest' do
      before { allow(server_info).to receive(:version).and_return(110) }

      it 'marks server as updated' do
        server.save_version_info(server_info)
        expect(server.reload.update_status).to eq('Updated')
        expect(server.last_known_version).to eq(110)
      end
    end
  end

  describe '#detailed_location' do
    let(:server) { build_stubbed(:server, ip: '1.2.3.4') }

    before do
      # Bypass caching so each example exercises the resolver directly.
      allow(Rails.cache).to receive(:fetch) { |*_args, &block| block.call }
    end

    context 'when the server has no ip' do
      let(:server) { build_stubbed(:server, ip: nil) }

      it 'returns Unknown' do
        expect(server.detailed_location).to eq('Unknown')
      end
    end

    context 'with a geocoding override' do
      it 'returns "City, State" for a USA location with a state' do
        allow(server).to receive(:geocoding_override_for).and_return(
          'city' => 'Chicago', 'state' => 'Illinois', 'country' => 'USA'
        )
        expect(server.detailed_location).to eq('Chicago, Illinois')
      end

      it 'returns "City, Country" for a non-USA location' do
        allow(server).to receive(:geocoding_override_for).and_return(
          'city' => 'Amsterdam', 'state' => 'North Holland', 'country' => 'Netherlands'
        )
        expect(server.detailed_location).to eq('Amsterdam, Netherlands')
      end

      it 'returns "City, Germany" for a German location with a state' do
        allow(server).to receive(:geocoding_override_for).and_return(
          'city' => 'Falkenstein', 'state' => 'Saxony', 'country' => 'Germany'
        )
        expect(server.detailed_location).to eq('Falkenstein, Germany')
      end
    end

    context 'without an override, using the geocoder' do
      before { allow(server).to receive(:geocoding_override_for).and_return(nil) }

      it 'returns "City, StateCode" for a USA result, using the subdivision iso code' do
        allow(server).to receive(:location).and_return(nil)
        result = double('GeoResult', city: 'New York', state: 'New York',
                                     country: 'USA',
                                     data: { 'subdivisions' => [ { 'iso_code' => 'NY' } ] })
        allow(Geocoder).to receive(:search).with('1.2.3.4').and_return([ result ])

        expect(server.detailed_location).to eq('New York, NY')
      end

      it 'prefers the server location name as the country for a non-USA result' do
        allow(server).to receive(:location).and_return(double('Location', name: 'Netherlands'))
        result = double('GeoResult', city: 'Amsterdam', state: nil, country: 'Netherlands')
        allow(Geocoder).to receive(:search).with('1.2.3.4').and_return([ result ])

        expect(server.detailed_location).to eq('Amsterdam, Netherlands')
      end

      it 'falls back to the location name when the geocoder has no usable result' do
        allow(server).to receive(:location).and_return(double('Location', name: 'Netherlands'))
        allow(Geocoder).to receive(:search).with('1.2.3.4').and_return([])

        expect(server.detailed_location).to eq('Netherlands')
      end

      it 'falls back to the location name when geocoding raises' do
        allow(server).to receive(:location).and_return(double('Location', name: 'Netherlands'))
        allow(Geocoder).to receive(:search).and_raise(StandardError, 'boom')

        expect(server.detailed_location).to eq('Netherlands')
      end
    end
  end

  describe 'resolved_ip maintenance' do
    it 'resolves the ip after it changes on save' do
      server = create(:server, ip: '1.2.3.4', port: '27015')

      expect_any_instance_of(PopulateResolvedIpsService).to receive(:update_server).with(server)

      server.update!(ip: '5.6.7.8')
    end

    it 'resolves the ip when a new server is created' do
      expect_any_instance_of(PopulateResolvedIpsService).to receive(:update_server)

      create(:server, ip: '1.2.3.4', port: '27015')
    end

    it 'does not re-resolve when the ip is unchanged' do
      server = create(:server, ip: '1.2.3.4', port: '27015')

      expect_any_instance_of(PopulateResolvedIpsService).not_to receive(:update_server)

      server.update!(name: 'renamed but same ip')
    end
  end
end
