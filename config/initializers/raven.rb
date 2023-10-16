# frozen_string_literal: true

require 'raven'

Raven.configure do |config|
  config.dsn = Rails.application.credentials.dig(:sentry, :dsn)
  config.excluded_exceptions += ['ActionController::RoutingError', 'ActiveRecord::RecordNotFound', 'Mime::Type::InvalidMimeType', 'SteamCondenser::Error::RCONNoAuth']
end
