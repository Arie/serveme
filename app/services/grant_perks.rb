# typed: strict
# frozen_string_literal: true

class GrantPerks
  extend T::Sig

  sig { returns(Product) }
  attr_accessor :product

  sig { returns(User) }
  attr_accessor :user

  sig { params(product: Product, user: User).void }
  def initialize(product, user)
    @product  = product
    @user     = user
  end

  sig { void }
  def perform
    AddGroupMembership.new(product.days, user).perform
    AddGroupMembership.new(product.days, user, Group.private_user(user)).perform if product.grants_private_server?
  end
end
