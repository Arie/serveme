# frozen_string_literal: true
class StripeOrder < ActiveRecord::Base
  #   Stripe::Charge.create(
  #     amount: 2000,
  #     currency: 'usd',
  #     source: 'tok_189fq02eZvKYlo2CSZkIV8Cg', # obtained with Stripe.js
  #     description: 'Charge for zoey.robinson@example.com'
  #   )
end
