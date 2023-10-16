# frozen_string_literal: true

PayPal::SDK::Core::Config.load('config/paypal.yml', Rails.env)
PayPal::SDK.logger.level = Logger::WARN if Rails.env.test?
