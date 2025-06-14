# typed: false

class SdrController < ApplicationController
  def index
    if params[:ip_port].present?
      ip, port = extract_ip_port(params[:ip_port])
      if ip && port
        resolved_ip = nil
        begin
          unless ip.match?(/^\d+\.\d+\.\d+\.\d+$/)
            resolved_ip = Addrinfo.getaddrinfo(ip, nil, Socket::AF_INET)
              .first&.ip_address
          end
        rescue SocketError
        end

        @server = Server.active.where(port: port)
          .where("ip = ? OR resolved_ip = ? OR ip = ? OR resolved_ip = ?",
            ip, ip, resolved_ip, resolved_ip)
          .first

        if @server
          reservation = @server.current_reservation
          if reservation&.sdr_ip.present?
            @sdr_ip_port = "#{reservation.sdr_ip}:#{reservation.sdr_port}"
          elsif @server.last_sdr_ip.present?
            @sdr_ip_port = "#{@server.last_sdr_ip}:#{@server.last_sdr_port}"
          end
        end
      end
    end
  end

  private

  def extract_ip_port(input)
    input = input.gsub(/^(?:connect|connet)\s+/i, "")

    input = input.split(";").first.strip

    if match = input.match(/([^:]+):(\d+)$/)
      [ match[1], match[2] ]
    end
  end
end
