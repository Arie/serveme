# typed: false
# frozen_string_literal: true

class OrdersController < ApplicationController
  def new
    @products = Product.active.ordered
    @order = Order.new(gift: params[:gift], product: Product.find_by_name("1 year"))
  end

  def create
    respond_to do |format|
      format.html do
        order_params = params.require(:order).permit(%i[product_id gift payer_id])
        paypal_order.product_id = order_params[:product_id].to_i
        paypal_order.gift       = order_params[:gift]
        if paypal_order.save && paypal_order.prepare
          redirect_to paypal_order.checkout_url, allow_other_host: true
        else
          flash[:alert] = "Something went wrong creating your order, please try again"
          render :new, status: :unprocessable_entity
        end
      end
    end
  end

  def create_payment_intent
    order = current_user.stripe_orders.build(
      product_id: params[:product_id].to_i,
      gift: ActiveModel::Type::Boolean.new.cast(params[:gift])
    )

    if order.save
      result = order.create_payment_intent(params[:payment_method_id])
      result[:payment_intent_id] = order.payment_id
      render json: result
    else
      render json: { error: "Could not create order" }, status: :unprocessable_entity
    end
  end

  def confirm_payment
    order = current_user.stripe_orders.find_by(payment_id: params[:payment_intent_id])

    if order
      result = order.confirm_payment(params[:payment_intent_id])
      render json: result
    else
      render json: { error: "Order not found" }, status: :not_found
    end
  end

  def create_express_payment_intent
    order = current_user.stripe_orders.build(
      product_id: params[:product_id].to_i,
      gift: ActiveModel::Type::Boolean.new.cast(params[:gift])
    )

    if order.save
      result = order.create_express_payment_intent
      render json: result
    else
      render json: { error: "Could not create order" }, status: :unprocessable_entity
    end
  end

  def redirect
    if order.charge(params[:PayerID])
      if order.gift?
        flash[:notice] = "Your payment has been received and we've given you a premium code that you can give away"
        redirect_to settings_path(anchor: "your-vouchers"), data: { turbo: false }
      else
        flash[:notice] = "Your payment has been received and your donator perks are now activated, thanks! <3"
        redirect_to root_path
      end
    else
      flash[:alert] = "Something went wrong while trying to activate your donator status, please check if you have sufficient funds in your PayPal account"
      redirect_to root_path
    end
  end

  def stripe_return
    payment_intent_id = params[:payment_intent]
    order = current_user.stripe_orders.find_by(payment_id: payment_intent_id)

    if order
      Rails.logger.info "Processing return for order #{order.id} with payment_intent #{payment_intent_id}"
      result = order.confirm_payment(payment_intent_id)
      Rails.logger.info "Confirmation result: #{result.inspect}"

      if result[:success]
        if order.gift?
          flash[:notice] = "Your payment has been received and we've given you a premium code that you can give away"
          redirect_to settings_path(anchor: "your-vouchers"), data: { turbo: false }
        else
          flash[:notice] = "Your payment has been received and your donator perks are now activated, thanks! <3"
          redirect_to root_path
        end
      else
        flash[:alert] = result[:error]
        redirect_to new_order_path
      end
    else
      flash[:alert] = "Order not found"
      redirect_to new_order_path
    end
  rescue StandardError => e
    Rails.logger.error "Error in stripe_return: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    flash[:alert] = "An error occurred while processing your payment. Please contact support."
    redirect_to new_order_path
  end

  def status
    order = current_user.stripe_orders.find_by(payment_id: params[:payment_intent_id])

    if order
      render json: {
        status: order.status,
        gift: ActiveModel::Type::Boolean.new.cast(order.gift),
        voucher: order.voucher&.code
      }
    else
      render json: { error: "Order not found" }, status: :not_found
    end
  end

  private

  def order
    current_user.paypal_orders.find(params[:order_id].to_i)
  end

  def paypal_order
    @paypal_order ||= current_user.paypal_orders.build
  end
end
