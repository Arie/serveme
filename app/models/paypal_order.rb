# frozen_string_literal: true

class PaypalOrder < Order
  include PayPal::SDK::REST

  def prepare
    set_redirect_urls
    add_transaction
    if payment.create
      update(status: 'Redirected', payment_id: payment.id)

    else
      Raven.capture_exception(payment.error) if Rails.env.production?
      false
    end
  end

  def charge(payer_id, payment_class = Payment)
    payment = payment_class.find(payment_id)
    if payment.execute(payer_id: payer_id)
      handle_successful_payment!
    else
      update(status: 'Failed')
      false
    end
  end

  def set_redirect_urls
    payment.redirect_urls = RedirectUrls.new(
      return_url: "#{SITE_URL}/orders/redirect/?order_id=#{id}",
      cancel_url: "#{SITE_URL}/orders/new"
    )
  end

  def checkout_url
    @checkout_url ||= payment.links.find { |v| v.method == 'REDIRECT' }.href
  end

  def payment
    @payment ||= Payment.new(intent: 'sale',
                             payer: {
                               payment_method: 'paypal'
                             })
  end

  def amount
    Amount.new(currency: product.currency,
               total: format_price(product.price))
  end

  def add_transaction
    payment.transactions = [
      Transaction.new(amount: amount,
                      item_list: item_list)
    ]
  end

  def item_list
    ItemList.new(items: items)
  end

  def items
    [
      Item.new(name: "#{SITE_HOST} - #{product.name}",
               price: format_price(product.price),
               quantity: 1,
               currency: product.currency)
    ]
  end

  private

  def format_price(price)
    sprintf('%.2f' % price.round(2))
  end
end
