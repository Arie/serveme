class AnnounceDonatorWorker

  include Sidekiq::Worker

  def perform(paypal_order_id)
    @paypal_order = PaypalOrder.find(paypal_order_id)
    @user     = @paypal_order.user
    @product  = @paypal_order.product
    Server.active.each do |s|
      s.rcon_say("#{@user.nickname} just donated to serveme.tf - #{@product.name}!")
    end
  end


end
