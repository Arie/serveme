# typed: true
# frozen_string_literal: true

class GenerateOrderVoucher
  extend T::Sig

  attr_accessor :order

  sig { params(order: Order).void }
  def initialize(order)
    @order = order
  end

  sig { returns(Voucher) }
  def perform
    voucher = Voucher.generate!(order.product)
    voucher.order = order
    voucher.created_by = order.user
    voucher.save!
    voucher
  end
end
