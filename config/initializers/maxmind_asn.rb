require 'maxmind/geoip2'

$maxmind_asn = MaxMind::GeoIP2::Reader.new(
  database: Rails.root.join('doc', 'GeoLite2-ASN.mmdb').to_s
)
