#encoding: utf-8

class Product < ActiveRecord::Base
  has_many :paypal_orders
  validates_presence_of :name, :price

  def list_name
    "#{name} - #{price.round.to_i} #{currency}"
  end

  def self.active
    where(:active => true)
  end

  def self.ordered
    order(:price)
  end

end
