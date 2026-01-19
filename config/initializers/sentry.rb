# typed: strict
# frozen_string_literal: true

Sentry.init do |config|
  config.breadcrumbs_logger = [ :active_support_logger ]
  config.sdk_logger.level = ::Logger::WARN
  config.dsn = Rails.application.credentials.dig(:sentry, :dsn)
  config.excluded_exceptions += [ "ActionController::RoutingError", "ActiveRecord::RecordNotFound", "Mime::Type::InvalidMimeType", "SteamCondenser::Error::RCONNoAuth", "DiscordApiClient::RateLimitError" ]
  config.send_default_pii = true
end
