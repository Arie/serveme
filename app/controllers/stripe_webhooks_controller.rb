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
    endpoint_secret = Rails.application.credentials.dig(:stripe, :webhook_signing_secret)

    begin
      Stripe::Webhook.construct_event(
        payload, sig_header, endpoint_secret
      )
    rescue JSON::ParserError => e
      # Invalid payload
      puts "Error parsing payload: #{e.message}"
      status 400
      nil
    rescue Stripe::SignatureVerificationError => e
      # Invalid signature
      puts "Error verifying webhook signature: #{e.message}"
      status 400
      nil
    end
  end

  def event
    @event ||= verify_webhook_signature
  end
end
