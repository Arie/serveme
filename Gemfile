source :rubygems

gem 'rails'
gem 'haml'
gem 'mysql2'
gem 'thin',             :require => false
gem 'omniauth-openid'
gem 'omniauth-steam'
gem 'devise'
gem 'simple_form'
gem 'rubyzip',          :require => false
gem 'paper_trail'

group :development do
  gem 'quiet_assets'

  #Debugging
  gem 'pry-nav'

  #Deployment
  gem 'capistrano-ext'
  gem 'capistrano_colors'
  gem 'capistrano'
  gem 'rvm-capistrano'
end

group :test, :development do
  gem 'factory_girl_rails'
  gem 'rspec-rails'
end

group :production do
  gem "sentry-raven"
  gem 'dalli'
end

group :assets, :test do
  gem "libv8", "~> 3.11.8"
end

group :assets do
  gem 'uglifier'
  gem 'jquery-rails'
  gem 'compass-rails'
  gem 'sass-rails'
  gem 'bootstrap-sass'                            #<3 twitter bootstrap
  gem 'therubyracer', :require => 'v8'
  gem 'turbo-sprockets-rails3'
end
