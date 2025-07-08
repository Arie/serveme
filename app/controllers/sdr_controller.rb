# typed: false

class SdrController < ApplicationController
  skip_before_action :redirect_if_country_banned, only: [ :index ]

  def index
    @result = nil
    return unless params[:ip_port].present?

    original = params[:ip_port]
    ip, port = extract_ip_port(original)
    return unless ip && port

    resolved_ip = resolve_ip(ip)
    server = find_server(ip, port, resolved_ip)
    return unless server

    sdr_ip, sdr_port = get_sdr_details(server)
    return unless sdr_ip && sdr_port

    @result = build_result(original, sdr_ip, sdr_port)
  end

  private

  def resolve_ip(ip)
    return ip if ip.match?(/^\d+\.\d+\.\d+\.\d+$/)
    Addrinfo.getaddrinfo(ip, nil, Socket::AF_INET).first&.ip_address
  rescue SocketError
    nil
  end

  def find_server(ip, port, resolved_ip)
    Server.active.where(port: port)
      .where(ip: [ ip, resolved_ip ])
      .or(Server.active.where(port: port).where(resolved_ip: [ ip, resolved_ip ]))
      .first
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
      result = original.gsub(/([^:]+):(\d+)/, sdr)
      result = "connect #{result.strip}" unless result.strip.start_with?("connect ")
      result
    else
      sdr
    end
  end

  def extract_ip_port(input)
    input = input.gsub(/^(?:connect|connet)\s+/i, "")
    input = input.split(";").first.strip
    if match = input.match(/([^:]+):(\d+)$/)
      [ match[1], match[2] ]
    end
  end
end
