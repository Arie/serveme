class RemoveDefaultTypeForOrders < ActiveRecord::Migration[5.0]
  def up
    change_column_default(:paypal_orders, :type, nil)
  end
  def down
    change_column_default(:paypal_orders, :type, "PaypalOrder")
  end
end
