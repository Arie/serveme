# frozen_string_literal: true
class AnnounceDonatorWorker

  include Sidekiq::Worker

  def perform(paypal_order_id)
    @paypal_order = PaypalOrder.find(paypal_order_id)
    @user     = @paypal_order.user
    @product  = @paypal_order.product
    Server.active.each do |s|
      s.rcon_say("#{@user.nickname} just donated to serveme.tf - #{@product.name}! #{PaypalOrder.monthly_goal_percentage.round} percent of our monthly server bills are now taken care of")
      s.rcon_disconnect
    end
  end


end
