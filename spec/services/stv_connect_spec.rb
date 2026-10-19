# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe StvConnect do
  define_method(:parsed) do |input|
    c = described_class.parse(input)
    [ c.host, c.port, c.password ]
  end

  it 'reads the ways people paste a SourceTV address' do
    expect(parsed('connect 1.2.3.4:27020; password "tv"')).to eq([ '1.2.3.4', 27020, 'tv' ])
    expect(parsed('CONNECT 1.2.3.4:27020;password tv')).to eq([ '1.2.3.4', 27020, 'tv' ])
    expect(parsed('1.2.3.4:27015 tv')).to eq([ '1.2.3.4', 27015, 'tv' ])
    expect(parsed('bolus.fakkelbrigade.eu; password tv')).to eq([ 'bolus.fakkelbrigade.eu', 27020, 'tv' ])
    expect(parsed('bolus.fakkelbrigade.eu')).to eq([ 'bolus.fakkelbrigade.eu', 27020, nil ])
    expect(parsed('1.2.3.4:27020 password pw')).to eq([ '1.2.3.4', 27020, 'pw' ])
  end

  it 'refuses what is not an address' do
    [ '', ' ; password tv', 'http://x/y', '1.2.3.4:port', '1.2.3.4:123456' ].each do |bad|
      expect { described_class.parse(bad) }.to raise_error(StvConnect::Error)
    end
  end

  it 'builds a connect string' do
    expect(described_class.parse('1.2.3.4:27020 tv').connect_string).to eq('connect 1.2.3.4:27020; password "tv"')
    expect(described_class.parse('1.2.3.4').connect_string).to eq('connect 1.2.3.4:27020')
  end

  describe '#check!' do
    define_method(:reply) do |auth|
      lambda do |data|
        nonce = data.byteslice(5, 4).unpack1('V')
        [ 0xFFFFFFFF, 'A'.ord, StvConnect::MAGIC, 1234, nonce, auth ].pack('VCVVVV')
      end
    end

    define_method(:udp_server) do |&answer|
      socket = UDPSocket.new
      socket.bind('127.0.0.1', 0)
      thread = Thread.new do
        loop do
          data, from = socket.recvfrom(1400)
          socket.send(answer.call(data), 0, from[3], from[1])
        end
      end
      [ socket, thread ]
    end

    # The check refuses loopback, which these local servers are on.
    before { stub_const('StvConnect::NON_PUBLIC', []) }

    it 'accepts a SourceTV' do
      socket, thread = udp_server(&reply(StvConnect::AUTH_SOURCETV))
      port = socket.addr[1]
      expect(described_class.parse("127.0.0.1:#{port}").check!.port).to eq(port)
    ensure
      thread&.kill
      socket&.close
    end

    it 'says so when nothing answers' do
      socket = UDPSocket.new
      socket.bind('127.0.0.1', 0)
      stub_const('StvConnect::TIMEOUT', 0.2)
      expect { described_class.parse("127.0.0.1:#{socket.addr[1]}").check! }.to raise_error(StvConnect::Error, /No SourceTV answers/)
    ensure
      socket&.close
    end

    it 'says so for a game port without a SourceTV next to it' do
      socket, thread = udp_server(&reply(StvConnect::AUTH_STEAM))
      stub_const('StvConnect::TIMEOUT', 0.2)
      expect { described_class.parse("127.0.0.1:#{socket.addr[1]}").check! }.to raise_error(StvConnect::Error, /is a game server/)
    ensure
      thread&.kill
      socket&.close
    end

    it 'refuses private addresses' do
      stub_const('StvConnect::NON_PUBLIC', [ IPAddr.new('127.0.0.0/8') ])
      expect { described_class.parse('127.0.0.1:27020').check! }.to raise_error(StvConnect::Error, /not a public address/)
    end
  end
end
