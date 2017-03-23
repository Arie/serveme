# frozen_string_literal: true
stripe_file = 'config/stripe.yml'

if File.exist?(stripe_file)
  stripe_config = YAML.load_file(stripe_file).fetch(Rails.env.to_s) {}
  Stripe.api_key = stripe_config.fetch('api_key') {}
  STRIPE_PUBLISHABLE_KEY = stripe_config.fetch('publishable_key')
end
