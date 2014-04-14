class AddCurrencyToProducts < ActiveRecord::Migration
  def change
    add_column :products, :currency, :string
    Product.update_all(:currency => "EUR")
  end
end
