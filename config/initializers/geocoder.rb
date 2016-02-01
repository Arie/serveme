if Rails.env.test?
  Geocoder.configure(
    ip_lookup:        :maxmind_local,
  )
else
  Geocoder.configure(
    lookup:           :test,
    ip_lookup:        :maxmind_local,
    maxmind_local: {file: Rails.root.join('doc', 'GeoLiteCity.dat') },
    units:            :km,
    cache:            Rails.cache,
  )
end
Geocoder::Lookup::Test.set_default_stub(
  [
    {
      'latitude'     => 40.7143528,
      'longitude'    => -74.0059731,
      'address'      => 'New York, NY, USA',
      'state'        => 'New York',
      'state_code'   => 'NY',
      'country'      => 'United States',
      'country_code' => 'US'
    }
  ]
)
#Monkeypatch Geocoder so it caches maxmind local lookups
require 'geocoder/lookups/maxmind_local'

module Geocoder::Lookup
  class MaxmindLocal < Base
    def results(query)
      if cache and out = cache[query]
        @cache_hit = true
      else
        if configuration[:file]
          geoip_class = RUBY_PLATFORM == "java" ? JGeoIP : GeoIP
          result = geoip_class.new(configuration[:file]).city(query.to_s)
          out = result.nil? ? [] : [result.to_hash]
        elsif configuration[:package] == :city
          addr = IPAddr.new(query.text).to_i
          q = "SELECT l.country, l.region, l.city, l.latitude, l.longitude
            FROM maxmind_geolite_city_location l WHERE l.loc_id = (SELECT b.loc_id FROM maxmind_geolite_city_blocks b
            WHERE b.start_ip_num <= #{addr} AND #{addr} <= b.end_ip_num)"
          out = format_result(q, [:country_name, :region_name, :city_name, :latitude, :longitude])
        elsif configuration[:package] == :country
          addr = IPAddr.new(query.text).to_i
          q = "SELECT country, country_code FROM maxmind_geolite_country
            WHERE start_ip_num <= #{addr} AND #{addr} <= end_ip_num"
          out = format_result(q, [:country_name, :country_code2])
        end
        cache[query] = out
        @cache_hit = false
      end
      out
    end

    def cache
      if @cache.nil? and store = configuration.cache
        @cache = Geocoder::Cache.new(store, configuration.cache_prefix)
      end
      @cache
    end
  end
end
