# frozen_string_literal: true

stripe_file = 'config/stripe.yml'

if File.exist?(stripe_file)
  stripe_config = YAML.load_file(stripe_file, aliases: true).fetch(Rails.env.to_s, nil)
  Stripe.api_key = stripe_config.fetch('api_key', nil)
  STRIPE_PUBLISHABLE_KEY = stripe_config.fetch('publishable_key')
end
