# typed: true
# frozen_string_literal: true

class PaypalOrder < Order
  extend T::Sig
  include PayPal::SDK::REST

  sig { returns(T::Boolean) }
  def prepare
    set_redirect_urls
    add_transaction
    if payment.create
      update(status: "Redirected", payment_id: payment.id)
    else
      Sentry.capture_exception(payment.error) if Rails.env.production?
      false
    end
  end

  sig { params(payer_id: String, payment_class: T.class_of(PayPal::SDK::REST::DataTypes::Payment)).returns(T.any(T::Boolean, T.nilable(String))) }
  def charge(payer_id, payment_class = Payment)
    payment = payment_class.find(payment_id)
    if payment.execute(payer_id: payer_id)
      handle_successful_payment!
    else
      update(status: "Failed")
      false
    end
  end

  sig { void }
  def set_redirect_urls
    payment.redirect_urls = RedirectUrls.new(
      return_url: "#{SITE_URL}/orders/redirect/?order_id=#{id}",
      cancel_url: "#{SITE_URL}/orders/new"
    )
  end

  sig { returns(String) }
  def checkout_url
    @checkout_url ||= payment.links.find { |v| v.method == "REDIRECT" }.href
  end

  sig { returns(PayPal::SDK::REST::DataTypes::Payment) }
  def payment
    @payment ||= Payment.new(intent: "sale",
                             payer: {
                               payment_method: "paypal"
                             })
  end

  sig { returns(PayPal::SDK::REST::DataTypes::Amount) }
  def amount
    Amount.new(currency: T.must(product).currency,
               total: format_price(T.must(product).price))
  end

  sig { void }
  def add_transaction
    payment.transactions = [
      Transaction.new(amount: amount,
                      item_list: item_list)
    ]
  end

  sig { returns(PayPal::SDK::REST::DataTypes::ItemList) }
  def item_list
    ItemList.new(items: items)
  end

  sig { returns(T::Array[PayPal::SDK::REST::DataTypes::Item]) }
  def items
    [
      Item.new(name: "#{SITE_HOST} - #{T.must(product).name}",
               price: format_price(T.must(product).price),
               quantity: 1,
               currency: T.must(product).currency)
    ]
  end

  private

  sig { params(price: Numeric).returns(String) }
  def format_price(price)
    format("%.2f", price.round(2))
  end
end
