# frozen_string_literal: true

require 'simplecov'
require 'coveralls'
require 'sidekiq'
require 'sidekiq/testing'
Sidekiq::Testing.inline!

# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RAILS_ENV'] ||= 'test'
gem 'minitest'
require File.expand_path('../config/environment', __dir__)
require 'rspec/rails'
require 'json_expressions/rspec'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }

RSpec.configure do |config|
  config.include Delorean
  config.fixture_path = "#{::Rails.root}/spec/fixtures"
  config.use_transactional_fixtures = true
  config.infer_base_class_for_anonymous_controllers = false
  config.order = 'random'
  config.include FactoryBot::Syntax::Methods
  config.infer_spec_type_from_file_location!
  config.expect_with :rspec do |c|
    c.syntax = %i[should expect]
  end
  config.mock_with :rspec do |c|
    c.syntax = %i[should expect]
  end
  config.before(:suite) do
    Rails.cache.clear
  end
  config.after(:example, :map_archive) do
    Dir.glob(File.join(MAPS_DIR, '*.bsp*')).each do |file|
      FileUtils.rm(file)
    end
  end
end
VCR.configure do |c|
  c.cassette_library_dir = 'spec/fixtures/vcr'
  c.hook_into :webmock, :faraday
  c.configure_rspec_metadata!
end

Zonebie.set_random_timezone
