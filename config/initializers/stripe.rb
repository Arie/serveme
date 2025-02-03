# typed: true
# frozen_string_literal: true

if SITE_HOST == 'sea.serveme.tf'
  Stripe.api_key = Rails.application.credentials.dig(:stripe, :sea_api_key)
  STRIPE_PUBLISHABLE_KEY = Rails.application.credentials.dig(:stripe, :sea_publishable_key)
else
  Stripe.api_key = Rails.application.credentials.dig(:stripe, :api_key)
  STRIPE_PUBLISHABLE_KEY = Rails.application.credentials.dig(:stripe, :publishable_key)
end

# Update to latest API version that supports automatic_payment_methods
Stripe.api_version = '2023-10-16'
