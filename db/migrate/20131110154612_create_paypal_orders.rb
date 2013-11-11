class CreatePaypalOrders < ActiveRecord::Migration
  def up
    create_table :paypal_orders do |t|
      t.integer :user_id
      t.integer :product_id
      t.string  :payment_id,  :limit => 191
      t.string  :payer_id,    :limit => 191
      t.string  :status,      :limit => 191
      t.timestamps
    end
    add_index :paypal_orders, :user_id
    add_index :paypal_orders, :product_id
    add_index :paypal_orders, :payment_id
    add_index :paypal_orders, :payer_id
  end

  def down
    drop_table :paypal_orders
  end
end
