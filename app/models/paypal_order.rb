# frozen_string_literal: true
class PaypalOrder < Order
  include PaypalPayment

  def complete_payment!
    update_attributes(status: 'Completed')
    if gift?
      GenerateOrderVoucher.new(self).perform
    else
      GrantPerks.new(product, user).perform
    end
    announce_donator
  end
end
