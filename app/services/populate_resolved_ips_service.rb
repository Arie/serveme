# typed: true
# frozen_string_literal: true

class PopulateResolvedIpsService
  extend T::Sig

  sig { void }
  def self.call
    new.call
  end

  sig { params(server: Server).void }
  def update_server(server)
    return if Rails.env.test?

    begin
      ip = T.must(server.ip)
      if ip.match?(/^\d+\.\d+\.\d+\.\d+$/)
        resolved_ip = ip
      else
        resolved_ip = lookup_hostname(ip)
      end
      server.update_column(:resolved_ip, resolved_ip) if resolved_ip
    rescue SocketError, Encoding::InvalidByteSequenceError => e
      Rails.logger.error "Failed to resolve IP for server #{server.id} (#{server.ip}): #{e.class} - #{e.message}"
    end
  end

  sig { void }
  def call
    @cache = T.let({}, T.nilable(T::Hash[String, T.nilable(String)]))
    Server.active.find_each do |server|
      update_server(server)
    end
  end

  private

  sig { params(hostname: String).returns(T.nilable(String)) }
  def lookup_hostname(hostname)
    @cache ||= {}
    return @cache[hostname] if @cache.key?(hostname)

    resolved_ip = Addrinfo.getaddrinfo(hostname, nil, Socket::AF_INET)
      .first&.ip_address
    @cache[hostname] = resolved_ip
    resolved_ip
  end
end
