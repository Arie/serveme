# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe OrdersController do
  before do
    @user = create :user
    sign_in @user
  end

  let(:order) { create :paypal_order, user: @user }

  describe '#create' do
    it 'shows the form again when paypal processing failed' do
      paypal_order = double.as_null_object
      expect(paypal_order).to receive(:prepare).and_return(false)
      subject.stub(paypal_order: paypal_order)

      post :create, params: { order: { product_id: 1 } }
      expect(response).to render_template(:new)
    end
  end

  describe '#redirect' do
    it 'redirects back to root and sets the thank you message on successful payment' do
      order.should_receive(:charge).with('PayerID').and_return(true)
      subject.stub(:order).and_return(order)

      get :redirect, params: { order_id: order.id, PayerID: 'PayerID' }

      response.should redirect_to(root_path)
      flash[:notice].should == 'Your payment has been received and your donator perks are now activated, thanks! <3'
    end

    it 'redirects back to root and sets the problem message on unsuccessful payment' do
      order.should_receive(:charge).with('PayerID').and_return(false)
      subject.stub(:order).and_return(order)

      get :redirect, params: { order_id: order.id, PayerID: 'PayerID' }

      response.should redirect_to(root_path)
      flash[:alert].should == 'Something went wrong while trying to activate your donator status, please check if you have sufficient funds in your PayPal account'
    end

    it 'redirects to settings path if it was a gift' do
      order.update_attribute(:gift, true)
      order.should_receive(:charge).with('PayerID').and_return(true)
      subject.stub(:order).and_return(order)

      get :redirect, params: { order_id: order.id, PayerID: 'PayerID' }

      response.should redirect_to(settings_path(anchor: 'your-vouchers'))
      flash[:notice].should == "Your payment has been received and we've given you a premium code that you can give away"
    end
  end

  describe '#create_payment_intent', :vcr do
    let!(:product) { create(:product, active: true) }

    it 'returns the payment intent information on a successful creation' do
      post :create_payment_intent, params: { payment_method_id: 'pm_card_visa', product_id: product.id, gift: false }

      expect(response.status).to eql(200)
      expect(JSON.parse(response.body)).to include(
        'success' => true,
        'gift' => false,
        'voucher' => nil
      )
    end

    it 'returns a 422 if order creation failed' do
      post :create_payment_intent, params: { payment_method_id: 'pm_card_visa', product_id: 0, gift: false }

      expect(response.status).to eql(422)
      expect(JSON.parse(response.body)).to include('error' => 'Could not create order')
    end
  end

  describe '#stripe_return', :vcr do
    let!(:product) { create(:product, active: true) }
    let!(:order) { create(:stripe_order, user: @user, product: product, payment_id: 'pi_123') }

    it 'redirects to root path on successful payment' do
      allow_any_instance_of(StripeOrder).to receive(:confirm_payment).and_return({ success: true })

      get :stripe_return, params: { payment_intent: 'pi_123' }

      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq('Your payment has been received and your donator perks are now activated, thanks! <3')
    end

    it 'redirects to settings path if it was a gift' do
      order.update(gift: true)
      allow_any_instance_of(StripeOrder).to receive(:confirm_payment).and_return({ success: true })

      get :stripe_return, params: { payment_intent: 'pi_123' }

      expect(response).to redirect_to(settings_path(anchor: 'your-vouchers'))
      expect(flash[:notice]).to eq("Your payment has been received and we've given you a premium code that you can give away")
    end

    it 'redirects to new order path if payment failed' do
      allow_any_instance_of(StripeOrder).to receive(:confirm_payment).and_return({ error: 'Payment failed' })

      get :stripe_return, params: { payment_intent: 'pi_123' }

      expect(response).to redirect_to(new_order_path)
      expect(flash[:alert]).to eq('Payment failed')
    end
  end

  describe '#status', :vcr do
    let!(:product) { create(:product, active: true) }
    let!(:order) { create(:stripe_order, user: @user, product: product, payment_id: 'pi_123', gift: true) }

    it 'returns the order status information' do
      get :status, params: { payment_intent_id: 'pi_123' }

      expect(response.status).to eql(200)
      expect(JSON.parse(response.body)).to include(
        'status' => order.status,
        'gift' => true,
        'voucher' => nil
      )
    end

    it 'returns 404 if order not found' do
      get :status, params: { payment_intent_id: 'pi_not_found' }

      expect(response.status).to eql(404)
      expect(JSON.parse(response.body)).to include('error' => 'Order not found')
    end
  end
end
