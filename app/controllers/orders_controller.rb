# frozen_string_literal: true
class OrdersController < ApplicationController

  skip_before_action :block_users_with_expired_reservations

  def new
    @products = Product.active.ordered
    @order = Order.new(gift: params[:gift], product: Product.find_by_name("1 year"))
  end

  def create
    order_params = params.require(:order).permit([:product_id, :gift])
    paypal_order.product_id = order_params[:product_id].to_i
    paypal_order.gift       = order_params[:gift]
    if paypal_order.save && paypal_order.prepare
      redirect_to paypal_order.checkout_url
    else
      flash[:alert] = "Something went wrong creating your order, please try again"
      render :new
    end
  end

  def redirect
    if order.charge(params[:PayerID])
      if order.gift?
        flash[:notice] = "Your payment has been received and we've given you a premium code that you can give away"
        redirect_to settings_path("#your-vouchers")
      else
        flash[:notice] = "Your payment has been received and your donator perks are now activated, thanks! <3"
        redirect_to root_path
      end
    else
      flash[:alert] = "Something went wrong while trying to activate your donator status, please check if you have sufficient funds in your PayPal account"
      redirect_to root_path
    end
  end

  def stripe
    $lock.synchronize("stripe-charge-#{current_user.id}") do
      if params[:stripe_token] && params[:product_id] && params[:gift]
        order = current_user.stripe_orders.build
        order.payer_id = params[:stripe_token]
        order.product = Product.active.find(params[:product_id].to_i)
        order.gift = (params[:gift] == "true")
        order.save!
        charge = order.charge
        if charge == "succeeded"
          render plain: { charge_status: charge, product_name: order.product_name, gift: order.gift, voucher: order.voucher.try(:code) }.to_json
        else
          render plain: { charge_status: charge }.to_json, status: 402
        end
      end
    end
  end

  def order
    current_user.paypal_orders.find(params[:order_id].to_i)
  end

  def paypal_order
    @paypal_order ||= current_user.paypal_orders.build
  end

end
