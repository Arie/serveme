# frozen_string_literal: true
class StripeOrder < Order
  def charge
    begin
      stripe_charge = Stripe::Charge.create(
        capture: true,
        amount: product.price_in_cents,
        currency: product.currency,
        description: "#{SITE_URL} - #{product_name}",
        source: payer_id,
        metadata: {
          site_url: SITE_URL,
          order_id: id,
          steam_uid: user.uid,
          product_name: product_name,
        }
      )
      if stripe_charge.status == "succeeded"
        update_attributes(status: 'Completed')
        if gift?
          GenerateOrderVoucher.new(self).perform
        else
          GrantPerks.new(product, user).perform
        end
        announce_donator
      end
      stripe_charge.status
    rescue Stripe::CardError => e
      e.message
    end
  end
end
