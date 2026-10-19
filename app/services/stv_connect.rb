# typed: true
# frozen_string_literal: true

require "socket"
require "resolv"

# A SourceTV address as people paste it (`connect host:27020; password "tv"`, `host:27020 tv`,
# `host`), and a quick check that a SourceTV answers there before the live map is sent to it.
# The check is the first packet of a spectator's handshake: SourceTV answers it with its
# authentication protocol, so it also tells a game port (which wants a Steam login) apart.
class StvConnect
  extend T::Sig

  class Error < StandardError; end

  DEFAULT_PORT = 27020
  TIMEOUT = 1.5
  AUTH_SOURCETV = 2
  AUTH_STEAM = 3
  MAGIC = 0x5A4F4933
  NON_PUBLIC = %w[0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12
                  192.168.0.0/16 224.0.0.0/3].map { |n| IPAddr.new(n) }.freeze

  attr_reader :host, :port, :password

  sig { params(host: String, port: Integer, password: T.nilable(String)).void }
  def initialize(host, port, password)
    @host = host
    @port = port
    @password = password
  end

  sig { params(input: String, password: T.nilable(String)).returns(StvConnect) }
  def self.parse(input, password = nil)
    line = input.strip.sub(/\Aconnect\s+/i, "")
    first, *rest = line.split(";")
    address, inline = first.to_s.strip.split(/\s+/, 2)
    pass = inline&.sub(/\Apassword\s*/, "")
    rest.each { |part| pass = part.strip.delete_prefix("password") if part.strip.start_with?("password") }
    pass = password if password.present?
    host, port = address.to_s.delete('"').split(":", 2)
    raise Error, "Paste a connect string or an address like 1.2.3.4:27020" if host.blank? || host !~ /\A[A-Za-z0-9.-]+\z/
    raise Error, "#{port} is not a port" if port && port !~ /\A\d{1,5}\z/

    new(host, port ? port.to_i : DEFAULT_PORT, pass.to_s.strip.delete_prefix('"').delete_suffix('"').presence)
  end

  sig { returns(String) }
  def connect_string
    password ? %(connect #{host}:#{port}; password "#{password}") : "connect #{host}:#{port}"
  end

  # Checks that a SourceTV answers, moving to game port + 5 (SourceTV's default) when given the
  # game port. Raises Error with what is wrong.
  sig { returns(StvConnect) }
  def check!
    ip = resolve
    case challenge(ip, port)
    when AUTH_SOURCETV then self
    when AUTH_STEAM
      raise Error, "#{host}:#{port} is a game server, and no SourceTV answers on #{port + 5}" unless challenge(ip, port + 5) == AUTH_SOURCETV

      @port = port + 5
      self
    else raise Error, "No SourceTV answers at #{host}:#{port}. Is SourceTV on (tv_enable 1), and is this its port?"
    end
  end

  private

  sig { returns(IPAddr) }
  def resolve
    address = host if host.match?(Resolv::IPv4::Regex)
    address ||= begin
      dns = Resolv::DNS.new
      dns.timeouts = 2
      dns.getaddresses(host).find { |a| a.is_a?(Resolv::IPv4) }&.to_s
    ensure
      dns&.close
    end
    raise Error, "#{host} has no IPv4 address" unless address

    ip = IPAddr.new(address)
    raise Error, "#{host} is not a public address" if NON_PUBLIC.any? { |n| n.include?(ip) }

    ip
  rescue Resolv::ResolvError, ArgumentError
    raise Error, "#{host} has no IPv4 address"
  end

  # The authentication protocol in the server's reply to a challenge request, or nil without one.
  # The reply may come from another address than the one asked (a server next to us behind
  # Docker's NAT answers from the bridge gateway), so any reply on the port with our nonce counts.
  sig { params(ip: IPAddr, port: Integer).returns(T.nilable(Integer)) }
  def challenge(ip, port)
    nonce = SecureRandom.random_number(2**32)
    socket = UDPSocket.new
    begin
      socket.send([ 0xFFFFFFFF, "q".ord, nonce ].pack("VCV") + "0000000000\0", 0, ip.to_s, port)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + TIMEOUT
      loop do
        left = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        return nil if left <= 0 || !socket.wait_readable(left)

        data, from = socket.recvfrom(1400)
        next unless from[1] == port && data.bytesize >= 21 && data.byteslice(0, 5) == "\xFF\xFF\xFF\xFFA".b

        magic, _server, echoed, auth = data.byteslice(5, 16).unpack("VVVV")
        return auth if magic == MAGIC && echoed == nonce
      end
    rescue SystemCallError
      nil
    ensure
      socket.close
    end
  end
end
