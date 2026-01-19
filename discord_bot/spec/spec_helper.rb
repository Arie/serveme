# typed: false
# frozen_string_literal: true

# Discord bot specs now require Rails environment since we use Rails directly
ENV["RAILS_ENV"] = "test"

# Load Rails environment
require_relative "../../config/environment"

# Load rspec-rails and FactoryBot
require "rspec/rails"
require "factory_bot_rails"

# Load bot libraries
require_relative "../lib/config"
require_relative "../lib/formatters/server_formatter"
require_relative "../lib/formatters/reservation_formatter"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.order = :random

  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods

  # Use transactions for database cleanup
  config.use_transactional_fixtures = true
end
