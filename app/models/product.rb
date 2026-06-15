# typed: strict
# frozen_string_literal: true

class Product < ActiveRecord::Base
  extend T::Sig

  has_many :orders
  validates_presence_of :name, :price

  sig { returns(String) }
  def list_name
    "#{name} - #{price.round.to_i} #{currency}"
  end

  sig { returns(Integer) }
  def price_in_cents
    price.round * 100
  end

  scope :active, -> { where(active: true) }

  scope :ordered, -> { order(:price) }
end
