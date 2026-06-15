# typed: true
# frozen_string_literal: true

class SdrResolver
  extend T::Sig

  Result = Struct.new(:original, :sdr_ip, :sdr_port, :connect_string, keyword_init: true)

  sig { params(input: T.untyped).returns(T.nilable(Result)) }
  def self.resolve(input)
    new(input).resolve
  end

  sig { params(input: T.untyped).void }
  def initialize(input)
    @original = T.let(input.to_s, String)
  end

  sig { returns(T.nilable(Result)) }
  def resolve
    ip, port = extract_ip_port(@original)
    return nil unless ip && port

    server = find_server(ip, port)
    return nil unless server

    sdr_ip, sdr_port = get_sdr_details(server)
    return nil unless sdr_ip && sdr_port

    Result.new(
      original: @original,
      sdr_ip: sdr_ip,
      sdr_port: sdr_port,
      connect_string: build_result(@original, sdr_ip, sdr_port)
    )
  end

  private

  sig { params(input: String).returns(T.nilable(T::Array[T.nilable(String)])) }
  def extract_ip_port(input)
    input = input.gsub(/^(?:connect|connet)\s+/i, "")
    input = input.split(";").first&.strip
    return unless input.present?

    if (match = input.match(/([^:]+):(\d+)$/))
      [ match[1], match[2] ]
    end
  end

  sig { params(ip: String, port: String).returns(T.nilable(Server)) }
  def find_server(ip, port)
    server = match_server(ip, port)
    return server if server
    return if ip.match?(/^\d+\.\d+\.\d+\.\d+$/)

    resolved_ip = resolve_hostname(ip)
    resolved_ip && match_server(resolved_ip, port)
  end

  sig { params(ip: String, port: String).returns(T.nilable(Server)) }
  def match_server(ip, port)
    scope = Server.active.where(port: port)
    scope.where(ip: ip).or(scope.where(resolved_ip: ip)).first
  end

  sig { params(hostname: String).returns(T.nilable(String)) }
  def resolve_hostname(hostname)
    Addrinfo.getaddrinfo(hostname, nil, Socket::AF_INET).first&.ip_address
  rescue SocketError
    nil
  end

  sig { params(server: Server).returns(T::Array[T.nilable(String)]) }
  def get_sdr_details(server)
    reservation = server.current_reservation
    sdr_ip = reservation&.sdr_ip.presence || server.last_sdr_ip
    sdr_port = reservation&.sdr_port.presence || server.last_sdr_port
    [ sdr_ip, sdr_port ]
  end

  sig { params(original: String, sdr_ip: T.nilable(String), sdr_port: T.nilable(String)).returns(String) }
  def build_result(original, sdr_ip, sdr_port)
    sdr = "#{sdr_ip}:#{sdr_port}"
    if original.match?(/connect|connet/i)
      result = original.sub(/([^:]+):(\d+)/, sdr)
      result = "connect #{result.strip}" unless result.strip.start_with?("connect ")
      result
    else
      sdr
    end
  end
end
