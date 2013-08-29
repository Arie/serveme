source 'https://rubygems.org'

gem 'rails', '~> 4.0.0'
gem 'protected_attributes'
gem "actionpack-action_caching"

gem 'paper_trail', :github => 'airblade/paper_trail', :branch => 'rails4'
gem 'haml'
gem 'mysql2'
#For NA
gem 'puma'
gem 'omniauth-openid'
gem 'omniauth-steam'
gem 'devise'
gem 'simple_form', "3.0.0.rc"
gem 'rubyzip',          :require => 'zip'
gem 'steam-condenser',  :github => 'Arie/steam-condenser-ruby'
gem 'logs_tf'
gem 'sys-proctable',    :require => 'sys/proctable'
gem 'net-ssh-simple'
gem 'draper'
gem 'will_paginate'
gem 'will_paginate-bootstrap'
gem 'zeroclipboard-rails', '0.0.5.beta1'
gem 'cronic'
gem "google_visualr"
gem 'rack-cache'

group :development do
  gem 'better_errors'
  gem 'thin',             :require => false
  gem 'binding_of_caller'

  #Deployment
  gem 'capistrano-ext'
  gem 'capistrano_colors'
  gem 'capistrano'
  gem 'capistrano-maintenance'
  gem 'rvm-capistrano'
  gem 'query_reviewer'
end

group :test, :development do
  gem 'factory_girl_rails'
  gem 'rspec-rails'
  gem 'pry-nav'
  gem 'zonebie'
end

group :test_tools do
  gem 'coveralls', require: false
  gem 'fuubar'
end

group :cucumber do
  gem 'cucumber-rails', :require => false, git: 'https://github.com/cucumber/cucumber-rails.git'
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
  gem 'shoulda-matchers'
  gem "libv8", "~> 3.11.8"
end

gem 'uglifier'
gem 'jquery-rails'
gem "compass-rails", '2.0.alpha.0' #github: "milgner/compass-rails", ref: "1749c06f15dc4b058427e7969810457213647fb8"
gem 'sass-rails'
gem 'bootstrap-sass'
gem 'therubyracer', :require => 'v8'
gem 'font-awesome-rails'
gem 'oily_png'
gem 'coffee-rails'
