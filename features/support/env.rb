# typed: false
# frozen_string_literal: true

require 'simplecov'
require 'coveralls'

require 'cucumber/rails'
require 'cucumber/rspec/doubles'
require 'sidekiq'
require 'sidekiq/testing'
require 'factory_bot_rails'
require 'rspec/sorbet'
RSpec::Sorbet.allow_doubles!
Sidekiq::Testing.inline!

# Load seed data
require Rails.root.join('db', 'seeds')
# Set server dir to rails tmp directory so we can write reservation.cfg for tests
Server.update_all(path: Rails.root.join('tmp').to_s)

Before do
  include ActionDispatch::TestProcess::FixtureFile
end

After do
  FileUtils.rm_rf(ActiveStorage::Blob.service.root)
end

at_exit do
  Server.delete_all
end

Capybara.default_selector = :css

ActionController::Base.allow_rescue = false

begin
  DatabaseCleaner.strategy = :transaction
rescue NameError
  raise 'You need to add database_cleaner to your Gemfile (in the :test group) if you wish to use it.'
end

Cucumber::Rails::Database.javascript_strategy = :truncation

# No need to type FactoryBot all the time
World(FactoryBot::Syntax::Methods)

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.command_name 'Cucumber'
end
