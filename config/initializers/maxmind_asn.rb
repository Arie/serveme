require 'maxmind/geoip2'

$maxmind_asn = if Rails.env.test?
                 MaxMind::GeoIP2::Reader.new(
                   database: Rails.root.join('doc', 'GeoLite2-ASN-Test.mmdb').to_s
                 )
               else
                 MaxMind::GeoIP2::Reader.new(
                   database: Rails.root.join('doc', 'GeoLite2-ASN.mmdb').to_s
                 )
               end
