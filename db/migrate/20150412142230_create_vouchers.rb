class CreateVouchers < ActiveRecord::Migration
  def change
    create_table :vouchers do |t|
      t.string :code, index: true, uniq: true
      t.integer :product_id, index: true
      t.datetime :claimed_at
      t.integer :claimed_by, index: true
      t.timestamps
    end
  end
end
