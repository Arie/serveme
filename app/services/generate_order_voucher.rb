# frozen_string_literal: true
class GenerateOrderVoucher
  attr_accessor :order

  def initialize(order)
    @order = order
  end

  def perform
    voucher = Voucher.generate!(order.product)
    voucher.order = order
    voucher.created_by = order.user
    voucher.save!
    voucher
  end
end
