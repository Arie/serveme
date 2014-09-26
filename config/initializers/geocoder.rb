Geocoder.configure(
  lookup:           :test,
  ip_lookup:        :maxmind_local,
  maxmind_local:    {package: :city},
  units:            :km,
  cache:            Redis.new,
)
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
