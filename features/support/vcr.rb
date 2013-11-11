require 'vcr'

VCR.cucumber_tags do |t|
  t.tag '@vcr'
end

VCR.configure do |c|
  c.cassette_library_dir = "features/fixtures/vcr"
  c.hook_into :webmock
end
