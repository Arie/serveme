# typed: false
# frozen_string_literal: true

require "opentelemetry/sdk"
# Load the rails application
require File.expand_path("application", __dir__)

# Initialize the rails application
Serveme::Application.initialize!
