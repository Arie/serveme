# typed: true
# frozen_string_literal: true

class StripeOrder < Order
  extend T::Sig

  sig { params(payment_method_id: String).returns(T::Hash[String, T.any(String, T::Boolean)]) }
  def create_payment_intent(payment_method_id)
    intent = Stripe::PaymentIntent.create(
      amount: product&.price_in_cents,
      currency: product&.currency,
      payment_method: payment_method_id,
      confirm: true,
      description: "#{SITE_URL} - #{product_name}",
      return_url: "#{SITE_URL}/orders/stripe_return",
      automatic_payment_methods: {
        enabled: true,
        allow_redirects: 'never'
      },
      metadata: {
        site_url: SITE_URL,
        order_id: id,
        steam_uid: user&.uid,
        product_name: product_name
      }
    )

    update(payment_id: intent.id)

    if intent.status == 'requires_action'
      {
        requires_action: true,
        payment_intent_client_secret: intent.client_secret
      }
    elsif intent.status == 'succeeded'
      handle_successful_payment!
      {
        success: true,
        gift: gift?,
        voucher: voucher&.code
      }
    else
      { error: 'Payment failed' }
    end
  rescue Stripe::CardError => e
    { error: e.message }
  end

  sig { params(payment_intent_id: String).returns(T::Hash[String, T.any(String, T::Boolean)]) }
  def confirm_payment(payment_intent_id)
    intent = Stripe::PaymentIntent.retrieve(payment_intent_id)

    if intent.status == 'succeeded'
      handle_successful_payment!
      {
        success: true,
        gift: gift?,
        voucher: voucher&.code
      }
    elsif intent.status == 'requires_confirmation'
      # Confirm the payment if needed
      intent.confirm({
                       return_url: "#{SITE_URL}/orders/stripe_return",
                       automatic_payment_methods: {
                         enabled: true,
                         allow_redirects: 'never'
                       }
                     })
      if intent.status == 'succeeded'
        handle_successful_payment!
        {
          success: true,
          gift: gift?,
          voucher: voucher&.code
        }
      else
        { error: 'Payment confirmation failed', status: intent.status }
      end
    else
      { error: "Payment confirmation failed - status: #{intent.status}" }
    end
  rescue Stripe::CardError => e
    { error: e.message }
  end
end
