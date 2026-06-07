# typed: true
# frozen_string_literal: true

class SdrResolver
  Result = Struct.new(:original, :sdr_ip, :sdr_port, :connect_string, keyword_init: true)

  def self.resolve(input)
    new(input).resolve
  end

  def initialize(input)
    @original = input.to_s
  end

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

  def extract_ip_port(input)
    input = input.gsub(/^(?:connect|connet)\s+/i, "")
    input = input.split(";").first&.strip
    return unless input.present?

    if (match = input.match(/([^:]+):(\d+)$/))
      [ match[1], match[2] ]
    end
  end

  def find_server(ip, port)
    server = match_server(ip, port)
    return server if server
    return if ip.match?(/^\d+\.\d+\.\d+\.\d+$/)

    resolved_ip = resolve_hostname(ip)
    resolved_ip && match_server(resolved_ip, port)
  end

  def match_server(ip, port)
    scope = Server.active.where(port: port)
    scope.where(ip: ip).or(scope.where(resolved_ip: ip)).first
  end

  def resolve_hostname(hostname)
    Addrinfo.getaddrinfo(hostname, nil, Socket::AF_INET).first&.ip_address
  rescue SocketError
    nil
  end

  def get_sdr_details(server)
    reservation = server.current_reservation
    sdr_ip = reservation&.sdr_ip.presence || server.last_sdr_ip
    sdr_port = reservation&.sdr_port.presence || server.last_sdr_port
    [ sdr_ip, sdr_port ]
  end

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
