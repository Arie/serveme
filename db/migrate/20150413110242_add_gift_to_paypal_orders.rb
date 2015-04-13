class AddGiftToPaypalOrders < ActiveRecord::Migration
  def change
    add_column :paypal_orders, :gift, :boolean, default: false
  end
end
