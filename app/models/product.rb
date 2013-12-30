#encoding: utf-8

class Product < ActiveRecord::Base
  has_many :paypal_orders
  validates_presence_of :name, :price

  def list_name
    "#{name} - #{price.round} EUR"
  end

  def self.active
    where(:active => true)
  end


end
