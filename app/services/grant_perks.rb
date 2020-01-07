# frozen_string_literal: true

class GrantPerks
  attr_accessor :product, :user

  def initialize(product, user)
    @product  = product
    @user     = user
  end

  def perform
    AddGroupMembership.new(product.days, user).perform
    if product.grants_private_server?
      AddGroupMembership.new(product.days, user, Group.private_user(user)).perform
    end
  end
end
