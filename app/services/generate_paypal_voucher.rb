class GeneratePaypalVoucher

  attr_accessor :paypal_order

  def initialize(paypal_order)
    @paypal_order = paypal_order
  end

  def perform
    voucher = Voucher.generate!(paypal_order.product)
    voucher.paypal_order = paypal_order
    voucher.created_by   = paypal_order.user
    voucher.save!
    voucher
  end
end
