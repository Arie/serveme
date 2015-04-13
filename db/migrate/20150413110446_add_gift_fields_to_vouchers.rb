class AddGiftFieldsToVouchers < ActiveRecord::Migration
  def change
    add_column :vouchers, :created_by_id, :integer, index: true
    add_column :vouchers, :paypal_order_id, :integer, index: true
    rename_column :vouchers, :claimed_by, :claimed_by_id
  end
end
