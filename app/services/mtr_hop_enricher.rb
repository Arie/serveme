# typed: true
# frozen_string_literal: true

# Network and location for a hop address, looked up once per address per run.
class MtrHopEnricher
  extend T::Sig

  sig { void }
  def initialize
    @cache = T.let({}, T::Hash[String, T::Hash[String, T.untyped]])
  end

  sig { params(ip: String).returns(T::Hash[String, T.untyped]) }
  def host(ip)
    @cache[ip] ||= lookup(ip)
  end

  private

  def lookup(ip)
    return { "ip" => ip, "asn" => nil, "org" => "private", "city" => nil, "country" => nil } if internal?(ip)

    asn = ReservationPlayer.asn(ip)
    geo = Geocoder.search(ip).first
    { "ip" => ip, "asn" => asn&.autonomous_system_number, "org" => asn&.autonomous_system_organization, "net" => asn&.network&.to_s,
      "city" => geo&.city.presence, "country" => geo&.country_code.presence }
  rescue StandardError => e
    Rails.logger.warn "MtrHopEnricher: lookup failed for #{ip}: #{e.class}: #{e.message}"
    { "ip" => ip, "asn" => nil, "org" => nil, "city" => nil, "country" => nil }
  end

  def internal?(ip)
    addr = IPAddr.new(ip)
    addr.private? || addr.loopback? || addr.link_local? || IPAddr.new("100.64.0.0/10").include?(addr)
  rescue IPAddr::Error
    false
  end
end
