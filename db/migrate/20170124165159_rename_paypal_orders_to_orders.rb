# frozen_string_literal: true
class RenamePaypalOrdersToOrders < ActiveRecord::Migration
  def change
    rename_table :paypal_orders, :orders
    add_column :orders, :type, :string, default: 'paypal'
    rename_column :vouchers, :paypal_order_id, :order_id
  end
end
