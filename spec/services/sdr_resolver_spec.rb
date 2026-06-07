# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe SdrResolver do
  describe '.resolve' do
    let!(:server) do
      create :server, ip: '176.9.138.143', port: '27015',
                      last_sdr_ip: '169.254.1.2', last_sdr_port: '12345'
    end

    it 'resolves a bare ip:port to the SDR ip:port' do
      result = SdrResolver.resolve('176.9.138.143:27015')

      expect(result.sdr_ip).to eq('169.254.1.2')
      expect(result.sdr_port).to eq('12345')
      expect(result.connect_string).to eq('169.254.1.2:12345')
    end

    it 'rewrites a full connect string keeping the connect keyword and password' do
      result = SdrResolver.resolve('connect 176.9.138.143:27015; password "foo"')

      expect(result.connect_string).to eq('connect 169.254.1.2:12345; password "foo"')
    end

    it 'prefers the current reservation SDR details over the server defaults' do
      create :reservation, server: server, sdr_ip: '10.0.0.1', sdr_port: '54321',
                           starts_at: 1.minute.ago, ends_at: 1.hour.from_now

      result = SdrResolver.resolve('176.9.138.143:27015')

      expect(result.sdr_ip).to eq('10.0.0.1')
      expect(result.sdr_port).to eq('54321')
    end

    it 'returns nil when no server matches the ip and port' do
      expect(SdrResolver.resolve('1.1.1.1:27015')).to be_nil
    end

    it 'returns nil when the matched server has no SDR details' do
      server.update_columns(last_sdr_ip: nil, last_sdr_port: nil)

      expect(SdrResolver.resolve('176.9.138.143:27015')).to be_nil
    end

    it 'returns nil for input that has no parseable ip and port' do
      expect(SdrResolver.resolve('not a connect string')).to be_nil
    end

    it 'matches a numeric ip without any DNS lookup' do
      expect(Addrinfo).not_to receive(:getaddrinfo)

      expect(SdrResolver.resolve('176.9.138.143:27015').sdr_ip).to eq('169.254.1.2')
    end

    it 'matches a hostname against the server ip column without a DNS lookup' do
      create :server, ip: 'host.example.com', port: '27016',
                      last_sdr_ip: '1.1.1.1', last_sdr_port: '99'

      expect(Addrinfo).not_to receive(:getaddrinfo)

      result = SdrResolver.resolve('host.example.com:27016')
      expect(result.connect_string).to eq('1.1.1.1:99')
    end

    it 'falls back to resolving a hostname alias via DNS when no direct match exists' do
      create :server, ip: '5.5.5.5', port: '27017', resolved_ip: '5.5.5.5',
                      last_sdr_ip: '2.2.2.2', last_sdr_port: '88'
      expect(Addrinfo).to receive(:getaddrinfo).with('alias.example.com', nil, Socket::AF_INET)
        .and_return([ double(ip_address: '5.5.5.5') ])

      result = SdrResolver.resolve('alias.example.com:27017')
      expect(result.connect_string).to eq('2.2.2.2:88')
    end

    it 'returns nil for input that strips down to nothing without crashing' do
      [ 'connect ', ';', 'connect ;', '' ].each do |input|
        expect { SdrResolver.resolve(input) }.not_to raise_error
        expect(SdrResolver.resolve(input)).to be_nil
      end
    end

    it 'keeps a password containing a colon followed by digits intact' do
      result = SdrResolver.resolve('connect 176.9.138.143:27015; password "ab:12"')

      expect(result.connect_string).to eq('connect 169.254.1.2:12345; password "ab:12"')
    end
  end
end
