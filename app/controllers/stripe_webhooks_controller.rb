# typed: false
# frozen_string_literal: true

class StripeWebhooksController < ApplicationController
  protect_from_forgery except: :create
  skip_before_action :authenticate_user!
  before_action :verify_webhook_signature

  def create
    case event.type
    when 'payment_intent.succeeded'
      handle_payment_intent_succeeded(event.data.object)
    when 'payment_intent.payment_failed'
      handle_payment_intent_failed(event.data.object)
    end

    head :ok
  rescue JSON::ParserError
    head :bad_request
  end

  private

  def handle_payment_intent_succeeded(payment_intent)
    order = StripeOrder.find_by(payment_id: payment_intent.id)
    return unless order

    order.handle_successful_payment! unless order.status == 'Completed'
  end

  def handle_payment_intent_failed(payment_intent)
    order = StripeOrder.find_by(payment_id: payment_intent.id)
    return unless order

    order.update(status: 'Failed')
  end

  def verify_webhook_signature
    payload = request.raw_post
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']

    region_secret = case SITE_HOST
                   when 'serveme.tf'
                     :eu_wh_secret
                   when 'na.serveme.tf'
                     :na_wh_secret
                   when 'sea.serveme.tf'
                     :sea_wh_secret
                   when 'au.serveme.tf'
                     :au_wh_secret
                   else
                     :eu_wh_secret  # Fallback to EU
                   end

    endpoint_secret = Rails.application.credentials.dig(:stripe, region_secret)

    begin
      Stripe::Webhook.construct_event(
        payload, sig_header, endpoint_secret
      )
    rescue JSON::ParserError => e
      puts "Error parsing payload: #{e.message}"
      status 400
      nil
    rescue Stripe::SignatureVerificationError => e
      puts "Error verifying webhook signature: #{e.message}"
      status 400
      nil
    end
  end

  def event
    @event ||= verify_webhook_signature
  end
end
