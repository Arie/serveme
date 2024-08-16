# typed: false
# frozen_string_literal: true

if SITE_HOST == 'sea.serveme.tf'
  PayPal::SDK::Core::Config.load('config/paypal.yml', 'sea_production')
else
  PayPal::SDK::Core::Config.load('config/paypal.yml', Rails.env)
end
PayPal::SDK.logger.level = Logger::WARN if Rails.env.test?
