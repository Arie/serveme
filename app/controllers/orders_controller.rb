# frozen_string_literal: true
class OrdersController < ApplicationController
  skip_before_filter :block_users_with_expired_reservations

  def new
    @products = Product.active.ordered
    @order = Order.new
  end

  def create
  end

  def redirect
  end
end
