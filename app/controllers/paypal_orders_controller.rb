class PaypalOrdersController < ApplicationController

  skip_before_filter :block_users_with_expired_reservations

  def new
    @products = Product.active.ordered
    @paypal_order = PaypalOrder.new(:product => Product.find_by_name("1 year"))
  end

  def create
    order_params = params.require(:paypal_order).permit([:product_id, :gift])
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
        flash[:notice] = "Your donation has been received and we've made a voucher code that you can give away"
        redirect_to settings_path("#your-vouchers")
      else
        flash[:notice] = "Your donation has been received and your donator perks are now activated, thanks! <3"
        redirect_to root_path
      end
    else
      flash[:alert] = "Something went wrong while trying to activate your donator status, please contact us using the comment section"
      redirect_to root_path
    end
  end

  def order
    current_user.paypal_orders.find(params[:order_id].to_i)
  end

  def paypal_order
    @paypal_order ||= current_user.paypal_orders.build
  end

end
