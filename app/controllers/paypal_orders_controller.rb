class PaypalOrdersController < ApplicationController

  def new
    @paypal_order = PaypalOrder.new(:product_id => Product.last.id)
  end

  def create
    paypal_order.product_id = params[:paypal_order][:product_id].to_i
    if paypal_order.save && paypal_order.prepare
      redirect_to paypal_order.checkout_url
    else
      flash[:alert] = "Something went wrong creating your order, please try again"
      render :new
    end
  end

  def redirect
    if order.charge(params[:PayerID])
      flash[:notice] = "Your donation has been received and your donator perks are now activated, thanks! <3"
    else
      flash[:alert] = "Something went wrong while trying to activate your donator status, please contact us using the comment section"
    end
    redirect_to root_path
  end

  def order
    current_user.paypal_orders.find(params[:order_id].to_i)
  end

  def paypal_order
    @paypal_order ||= current_user.paypal_orders.build
  end


end
