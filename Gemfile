# frozen_string_literal: true

source "https://rubygems.org"

gem "actionpack-action_caching"
gem "american_date"
gem "aws-sigv4"
gem "aws-sdk-core", require: false
gem "aws-sdk-s3", require: false
gem "bcrypt_pbkdf"
gem "bootsnap", require: false
gem "bootstrap"
gem "carrierwave"
gem "cgi"
gem "connection_pool", "< 3"
gem "dante"
gem "devise"
gem "down"
gem "draper"
gem "ed25519"
gem "eventmachine"
gem "faraday"
gem "font-awesome-rails"
gem "geocoder"
gem "haml"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "jbuilder"
gem "jquery-rails"
gem "lograge"
gem "logs_tf"
gem "maxmind-geoip2"
gem "mini_racer"
gem "net-ftp"
gem "net-imap"
gem "net-pop"
gem "net-sftp"
gem "net-smtp"
gem "net-ssh"
gem "oily_png"
gem "omniauth"
gem "omniauth-rails_csrf_protection"
gem "omniauth-steam", git: "https://github.com/Arie/omniauth-steam.git"
gem "opentelemetry-exporter-otlp"
gem "opentelemetry-instrumentation-all"
gem "opentelemetry-sdk"
gem "pagy"
gem "paypal-sdk-rest"
gem "pg"
gem "puma"
gem "rack-attack"
gem "rack-utf8_sanitizer"
gem "rails", "~> 8.1.0"
gem "rbzip2"
# Use Redis for Action Cable
gem "redis"
gem "remote_lock", git: "https://github.com/Arie/remote_lock.git"
gem "ruby_parser", require: false
gem "rubyzip", require: "zip"
gem "sass"
gem "sassc"
gem "sass-rails"
gem "sd_notify"
gem "sentry-rails"
gem "sentry-ruby"
gem "sentry-sidekiq"
gem "sidekiq"
gem "sidekiq-cron"
gem "simple_form"
gem "sorbet-static-and-runtime"
gem "sprockets"
gem "sprockets-rails"
gem "steam-condenser", git: "https://github.com/Arie/steam-condenser-ruby.git"
gem "stripe", "~> 15.5"
gem "terser"
gem "text"
gem "tf2_line_parser"
gem "uri"
gem "ruby-openai"
gem "rswag"
gem "rswag-ui"

group :development do
  gem "better_errors"
  gem "capistrano", require: false
  gem "capistrano3-puma"
  gem "capistrano-bundler", require: false
  gem "capistrano-faster-assets", require: false
  gem "capistrano-maintenance", require: false
  gem "capistrano-rails", require: false
  gem "capistrano-rvm", require: false
  gem "capistrano-sidekiq", git: "https://github.com/Pharmony/capistrano-sidekiq.git", require: false
  gem "rubocop", require: false
  gem "rubocop-sorbet", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-rails", require: false
  gem "tapioca", "~> 0.17.10", require: false
  gem "claude-on-rails"
  gem "tidewave"
end

group :test, :development do
  gem "factory_bot_rails"
  gem "parallel_tests"
  gem "pry-nav"
  gem "rspec-activemodel-mocks"
  gem "rspec-collection_matchers"
  gem "rspec-rails"
  gem "rspec-sorbet"
  gem "zonebie"
end

group :test do
  gem "capybara"
  gem "cucumber", require: false
  gem "cucumber-rails", require: false
  gem "database_cleaner"
  gem "json_expressions"
  gem "launchy"
  gem "maxminddb"
  gem "rails-controller-testing"
  gem "shoulda-matchers"
  gem "vcr"
  gem "webmock"
end

group :development, :production do
  gem "hive_geoip2"
end

gem "brakeman", "~> 7.0", groups: %i[development test]
