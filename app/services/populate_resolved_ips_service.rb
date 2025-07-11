# typed: true

class PopulateResolvedIpsService
  def self.call
    new.call
  end

  def update_server(server)
    return if Rails.env.test?

    begin
      if server.ip.match?(/^\d+\.\d+\.\d+\.\d+$/)
        resolved_ip = server.ip
      else
        resolved_ip = lookup_hostname(server.ip)
      end
      server.update_column(:resolved_ip, resolved_ip) if resolved_ip
    rescue SocketError, Encoding::InvalidByteSequenceError => e
      Rails.logger.error "Failed to resolve IP for server #{server.id} (#{server.ip}): #{e.class} - #{e.message}"
    end
  end

  def call
    @cache = {}
    Server.active.find_each do |server|
      update_server(server)
    end
  end

  private

  def lookup_hostname(hostname)
    return @cache[hostname] if @cache.key?(hostname)

    resolved_ip = Addrinfo.getaddrinfo(hostname, nil, Socket::AF_INET)
      .first&.ip_address
    @cache[hostname] = resolved_ip
    resolved_ip
  end
end
