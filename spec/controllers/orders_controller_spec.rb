require 'spec_helper'

describe OrdersController do

  before do
    @user = create :user
    sign_in @user
  end

  let(:order) { create :paypal_order, :user => @user }

  describe '#create' do
    it 'shows the form again when paypal processing failed' do

      paypal_order = double.as_null_object
      expect(paypal_order).to receive(:prepare).and_return(false)
      subject.stub(:paypal_order => paypal_order)

      post :create, params: { :order => {:product_id => 1} }
      expect(response).to render_template(:new)
    end
  end

  describe "#redirect" do

    it "redirects back to root and sets the thank you message on successful payment" do
      order.should_receive(:charge).with("PayerID").and_return(true)
      subject.stub(:order).and_return(order)

      get :redirect, params: { order_id: order.id, PayerID: "PayerID" }

      response.should redirect_to(root_path)
      flash[:notice].should == "Your donation has been received and your donator perks are now activated, thanks! <3"
    end

    it "redirects back to root and sets the problem message on unsuccessful payment" do
      order.should_receive(:charge).with("PayerID").and_return(false)
      subject.stub(:order).and_return(order)

      get :redirect, params: { order_id: order.id, PayerID: "PayerID" }

      response.should redirect_to(root_path)
      flash[:alert].should == "Something went wrong while trying to activate your donator status, please check if you have sufficient funds in your PayPal account"
    end

    it "redirects to settings path if it was a gift" do
      order.update_attribute(:gift, true)
      order.should_receive(:charge).with("PayerID").and_return(true)
      subject.stub(:order).and_return(order)

      get :redirect, params: { order_id: order.id, PayerID: "PayerID" }

      response.should redirect_to(settings_path("#your-vouchers"))
      flash[:notice].should == "Your donation has been received and we've made a voucher code that you can give away"
    end

  end

  describe "#order" do

    it "finds the orders limited to the current user" do
      subject.stub(:params).and_return({:order_id => order.id})
      subject.order.should == order


      other_user_order = create(:paypal_order)
      subject.stub(:params).and_return({:order_id => other_user_order.id})
      expect{subject.order}.to raise_error(ActiveRecord::RecordNotFound)
    end

  end

  describe "#stripe", :vcr do
    let!(:product) { create(:product, active: true) }

    it "returns the order information on a succesful charge" do
      post :stripe, params: { stripe_id: 'stripe-id', product_id: product.id, gift: false }

      json = { charge_status: "succeeded", product_name: product.name, gift: false, voucher: nil }

      expect(response.status).to eql(200)
      expect(response.body).to match_json_expression(json)
    end

    it "returns a 402 if charging failed" do
      post :stripe, params: { stripe_id: 'stripe-id', product_id: product.id, gift: false }

      expect(response.status).to eql(402)
    end
  end
end
