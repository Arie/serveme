# frozen_string_literal: true

source 'https://rubygems.org'

gem 'american_date'
gem 'base32_pure'
gem 'bcrypt_pbkdf'
gem 'carrierwave'
gem 'clipboard-rails'
gem 'coffee-rails'
gem 'connection_pool'
gem 'dante'
gem 'devise'
gem 'draper'
gem 'ed25519'
gem 'eventmachine'
gem 'execjs'
gem 'faraday'
gem 'ffi'
gem 'font-awesome-rails'
gem 'gameye'
gem 'geocoder'
gem 'google_visualr', git: 'https://github.com/Arie/google_visualr.git'
gem 'haml'
gem 'hashie'
gem 'hiredis'
gem 'hotwire-rails'
gem 'importmap-rails'
gem 'jbuilder'
gem 'jquery-rails'
gem 'lograge'
gem 'logs_tf'
gem 'mechanize'
gem 'mini_racer'
gem 'net-sftp'
gem 'net-ssh'
gem 'oily_png'
gem 'omniauth'
gem 'omniauth-rails_csrf_protection', '~> 1.0'
gem 'omniauth-steam'
gem 'paypal-sdk-rest'
gem 'pg'
gem 'puma'
gem 'rack', '~> 2.1.4'
gem 'rack-cache'
gem 'rails', '~> 6.1.2'
gem 'rbzip2'
gem 'redis-rack-cache'
gem 'redis-rails'
gem 'remote_lock'
gem 'rexml'
gem 'rubyzip', require: 'zip'
gem 'sidekiq', '< 6'
gem 'sidekiq-cron'
gem 'simple_form', git: 'https://github.com/heartcombo/simple_form.git'
gem 'steam-condenser', git: 'https://github.com/koraktor/steam-condenser-ruby.git'
gem 'stripe'
gem 'tailwindcss-rails'
gem 'terser'
gem 'tf2_line_parser'
gem 'will_paginate'

group :development do
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'capistrano', require: false
  gem 'capistrano3-puma', '~> 4.0', require: false
  gem 'capistrano-bundler', require: false
  gem 'capistrano_colors', require: false
  gem 'capistrano-ext', require: false
  gem 'capistrano-faster-assets', require: false
  gem 'capistrano-maintenance', require: false
  gem 'capistrano-rails', require: false
  gem 'capistrano-rvm', require: false
  gem 'capistrano-sidekiq', require: false
  gem 'rubocop', require: false
end

group :test, :development do
  gem 'factory_bot_rails'
  gem 'irb'
  gem 'parallel_tests'
  gem 'pry-nav'
  gem 'rspec-activemodel-mocks'
  gem 'rspec-collection_matchers'
  gem 'rspec-expectations'
  gem 'rspec-mocks'
  gem 'rspec-rails'
  gem 'rspec-support'
  gem 'solargraph'
  gem 'zonebie'
end

group :test do
  gem 'capybara'
  gem 'cucumber'
  gem 'cucumber-rails', require: false
  gem 'database_cleaner'
  gem 'delorean'
  gem 'json_expressions'
  gem 'launchy'
  gem 'maxminddb'
  gem 'minitest'
  gem 'rails-controller-testing'
  gem 'shoulda-matchers'
  gem 'vcr'
  gem 'webmock'
end

group :test_tools do
  gem 'coveralls', require: false
end

group :development, :production do
  gem 'hive_geoip2'
end

group :production do
  gem 'sentry-raven'
end

# Use Redis for Action Cable
gem 'redis', '~> 4.1.4'
