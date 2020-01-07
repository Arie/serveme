# frozen_string_literal: true

module Geocoder
  module Lookup
    class MaxmindLocal
      private

      remove_method(:results)

      def results(query)
        return [] if query.to_s == 'no results'

        if query.to_s == '127.0.0.1'
          []
        else
          [{ request: '8.8.8.8', ip: '8.8.8.8', country_code2: 'US', country_code3: 'USA', country_name: 'United States', continent_code: 'NA', region_name: 'CA', city_name: 'Mountain View', postal_code: '94043', latitude: 37.41919999999999, longitude: -122.0574, dma_code: 807, area_code: 650, timezone: 'America/Los_Angeles' }]
        end
      end
    end
  end
end
