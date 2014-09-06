source 'https://rubygems.org'

gem 'rails', "~> 4.1.0"
gem 'sprockets'
gem 'haml'
gem 'protected_attributes'
gem "actionpack-action_caching"
gem 'puma'
gem 'omniauth-openid'
gem 'omniauth-steam'
gem 'devise'
gem 'rubyzip'
gem 'steam-condenser', :github => 'Arie/steam-condenser-ruby'
gem 'logs_tf'

#Map uploads
gem 'carrierwave'
gem 'rbzip2', :github => 'koraktor/rbzip2'

#Logdaemon
gem 'tf2_line_parser', :github => "Arie/tf2_line_parser"
gem 'eventmachine'
gem 'dante'

gem 'net-ssh-simple'
gem 'net-ssh'
gem 'net-sftp'
gem 'draper'
gem 'will_paginate'
gem 'zeroclipboard-rails'
gem "google_visualr"
gem 'rack-cache'
gem 'paypal-sdk-rest'
gem 'sidekiq'
gem 'sidetiq', github: 'camjackson/sidetiq', ref: '12ac51ceb4f5e99ff2940047b160bdfacad047b6'
gem 'sinatra', '>= 1.3.0', :require => nil
gem 'mechanize'
gem 'american_date'
gem 'jbuilder'

gem 'ffi'
gem 'mysql2'
gem 'therubyracer'
gem 'oily_png'
gem 'sys-proctable', '~> 0.9.4', :require => 'sys/proctable'

group :development do
  gem 'better_errors'
  gem 'binding_of_caller'

  #Deployment
  gem 'capistrano-ext'
  gem 'capistrano_colors'
  gem 'capistrano', "~> 2.0"
  gem 'capistrano-maintenance'
  gem 'capistrano-sidekiq' , github: 'seuros/capistrano-sidekiq'
  gem 'rvm-capistrano'
  gem 'query_reviewer'
end

group :test, :development do
  gem 'factory_girl_rails'
  gem 'rspec-rails'
  gem 'rspec-collection_matchers'
  gem 'rspec-activemodel-mocks'
  gem 'pry-nav'
  gem 'zonebie'
end

group :test_tools do
  gem 'coveralls', require: false
  gem 'fuubar'
end

group :cucumber do
  gem 'cucumber-rails'
  gem 'database_cleaner'
  gem 'launchy'
  gem 'capybara'
  gem 'selenium-webdriver'
  gem 'fuubar-cucumber'
end

group :production do
  gem "sentry-raven"
  gem 'dalli'
end

group :test do
  #Load minitest explicitly to work around shoulda issue
  gem "minitest"
  gem 'shoulda-matchers'
  gem 'vcr'
  gem 'webmock'
  gem 'delorean'
  gem 'json_expressions'
end

gem 'uglifier'
gem 'jquery-rails'
gem "compass-rails"
gem 'sass', '3.4.1'
gem 'sass-rails', '~> 5.0.0.beta1'
gem 'bootstrap-sass'
gem 'simple_form'
gem 'will_paginate-bootstrap'
gem 'execjs'
gem 'font-awesome-rails'
gem 'coffee-rails'
