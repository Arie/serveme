# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe Product do
  before { Product.destroy_all }

  describe '#list_name' do
    it 'is a name with the rounded price included for use in the dropdown' do
      subject.name = 'foobar'
      subject.price = 12.34
      subject.currency = 'EUR'
      subject.list_name.should == 'foobar - 12 EUR'
    end
  end

  describe '.active' do
    it 'returns only active products' do
      active = create :product, active: true
      _inactive = create :product, active: false
      Product.active.should == [ active ]
    end
  end

  describe '.ordered' do
    it 'orders by price' do
      middle  = create :product, price: 10
      last    = create :product, price: 15
      first   = create :product, price: 5

      Product.ordered.should == [ first, middle, last ]
    end
  end

  describe '#price_in_cents' do
    it 'returns the price in cents for Stripe' do
      product = build :product, price: 10
      expect(product.price_in_cents).to eql(1000)
    end
  end
end
