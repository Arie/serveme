# frozen_string_literal: true

source 'https://rubygems.org'

gem 'american_date'
gem 'base32_pure'
gem 'bcrypt_pbkdf'
gem 'bootsnap', require: false
gem 'bootstrap', '~> 4.6' # Something in 5 breaks popper, not going to fix that now
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
gem 'maxmind-geoip2'
gem 'mechanize'
gem 'mini_racer'
gem 'net-ftp'
gem 'net-imap'
gem 'net-pop'
gem 'net-sftp'
gem 'net-smtp'
gem 'net-ssh'
gem 'oily_png'
gem 'omniauth'
gem 'omniauth-rails_csrf_protection'
gem 'omniauth-steam'
gem 'paypal-sdk-rest'
gem 'pg'
gem 'puma', '< 7.0'
gem 'rack'
gem 'rack-cache'
gem 'rails'
gem 'rbzip2'
# Use Redis for Action Cable
gem 'redis'
gem 'redis-rack-cache'
gem 'redis-rails'
gem 'remote_lock', git: 'https://github.com/Arie/remote_lock.git'
gem 'rexml'
gem 'rubyzip', require: 'zip'
gem 'sass'
gem 'sassc'
gem 'sass-rails'
gem 'sidekiq', '< 7'
gem 'sidekiq-cron'
gem 'simple_form'
gem 'sprockets'
gem 'sprockets-rails'
gem 'steam-condenser', git: 'https://github.com/koraktor/steam-condenser-ruby.git'
gem 'stripe'
gem 'terser'
gem 'text', '~> 1.3'
gem 'tf2_line_parser'
gem 'will_paginate'
gem 'will_paginate-bootstrap4'

group :development do
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'capistrano', require: false
  gem 'capistrano3-puma', '~> 5.2', require: false
  gem 'capistrano-bundler', require: false
  gem 'capistrano_colors', require: false
  gem 'capistrano-ext', require: false
  gem 'capistrano-faster-assets', require: false
  gem 'capistrano-maintenance', require: false
  gem 'capistrano-rails', require: false
  gem 'capistrano-rvm', require: false
  gem 'capistrano-sidekiq', git: 'https://github.com/Pharmony/capistrano-sidekiq.git', require: false
  gem 'rubocop', require: false
  gem 'ruby-lsp', '~> 0.3.5'
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
