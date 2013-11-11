class CreateProducts < ActiveRecord::Migration
  class Product < ActiveRecord::Base
    attr_accessible :name, :price, :days
  end

  def up
    create_table :products do |t|
      t.string  :name
      t.decimal :price,     :precision => 15, :scale => 6, :null => false
      t.integer :days
    end

    Product.reset_column_information
    Product.create!(:name => "1 month",   :price => 1.00, :days => 31)
    Product.create!(:name => "6 months",  :price => 5.00, :days => 186)
    Product.create!(:name => "1 year",    :price => 9.00, :days => 366)
  end

  def down
    drop_table :products
  end
end
