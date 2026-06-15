# typed: strict
# frozen_string_literal: true

require "maxmind/geoip2"

asn_db = Rails.env.test? ? "GeoLite2-ASN-Test.mmdb" : "GeoLite2-ASN.mmdb"
asn_path = Rails.root.join("doc", asn_db).to_s

$maxmind_asn = if File.exist?(asn_path)
  MaxMind::GeoIP2::Reader.new(database: asn_path)
else
  Rails.logger.warn { "MaxMind ASN database missing at #{asn_path}; ASN lookups disabled" }
  nil
end
