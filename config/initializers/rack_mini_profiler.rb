# typed: false
# frozen_string_literal: true

# Backend perf profiling for admins. Production: badge + Server-Timing
# headers only appear once an admin hits any page (ApplicationController
# calls authorize_request and sets the cookie). Development: visible to
# everyone for ease of perf work.

return if Rails.env.test?
return unless defined?(Rack::MiniProfiler)

Rack::MiniProfiler.config.authorization_mode = Rails.env.production? ? :allow_authorized : :allow_all
Rack::MiniProfiler.config.position = "bottom-right"

Rack::MiniProfiler.config.enable_advanced_debugging_tools = true

# Production needs shared storage across puma workers; dev keeps it in-process.
if Rails.env.production?
  Rack::MiniProfiler.config.storage = Rack::MiniProfiler::RedisStore
  Rack::MiniProfiler.config.storage_options = { url: ENV["REDIS_URL"] }.compact
end
