# frozen_string_literal: true
class RenamePaypalOrdersToOrders < ActiveRecord::Migration[4.2]
  def change
    add_column :paypal_orders, :type, :string, default: 'PaypalOrder'
    rename_column :vouchers, :paypal_order_id, :order_id
  end
end
