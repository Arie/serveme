require 'simplecov'
require 'coveralls'

SimpleCov.start 'rails'

require 'cucumber/rails'
require 'cucumber/rspec/doubles'
require 'sidekiq'
require 'sidekiq/testing'
Sidekiq::Testing.inline!

#Load seed data
require Rails.root.join('db', 'seeds')
#Set server dir to rails tmp directory so we can write reservation.cfg for tests
Server.update_all(:path => Rails.root.join('tmp').to_s)

at_exit do
  Server.delete_all
end

#include Devise::Test::IntegrationHelpers

Capybara.default_selector = :css

ActionController::Base.allow_rescue = false

begin
  DatabaseCleaner.strategy = :transaction
rescue NameError
  raise "You need to add database_cleaner to your Gemfile (in the :test group) if you wish to use it."
end

Cucumber::Rails::Database.javascript_strategy = :truncation

# No need to type FactoryGirl all the time
World(FactoryGirl::Syntax::Methods)
