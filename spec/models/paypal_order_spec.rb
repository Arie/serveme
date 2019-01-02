require 'spec_helper'

describe PaypalOrder do

  describe '#handle_successful_payment!' do

    let(:order) { create(:paypal_order) }

    it "sets the status to completed" do
      order.handle_successful_payment!
      order.status.should == "Completed"
    end

  end

  context "paypal" do

    let(:order) { create(:paypal_order) }

    it "can create a payment on PayPal", :vcr do
      order.prepare
      order.checkout_url.should_not be_nil
    end

    describe "#prepare" do

      it "returns false when it couldn't create the payment" do
        payment = double(:create => false)
        order.stub(:set_redirect_urls)
        order.stub(:add_transaction)
        order.stub(:payment => payment)

        expect(order.prepare).to eql(false)
      end

      it "sets the status of the order to directed if it could create the payment" do
        payment = double(:create => true, :id => "payment_id")
        order.stub(:set_redirect_urls)
        order.stub(:add_transaction)
        order.stub(:payment => payment)

        expect(order.prepare).to eql(true)
        expect(order.status).to eql("Redirected")
      end

    end

    describe "#charge" do

      let(:payment) { double }
      let(:payment_class) { double }

      before do
        payment_class.should_receive(:find).with("payment_id").and_return(payment)
        order.stub(:payment_id => "payment_id")
      end

      it "complete the payment when it was able to charge paypal" do
        payment.should_receive(:execute).with(:payer_id => "payer_id").and_return(true)

        order.should_receive(:handle_successful_payment!)
        order.charge("payer_id", payment_class)
      end

      it "sets the state to failed when it wasn't able to charge paypal" do
        payment.should_receive(:execute).with(:payer_id => "payer_id").and_return(false)

        order.should_not_receive(:complete_payment!)
        order.should_receive(:update_attributes).with(:status => "Failed")
        order.charge("payer_id", payment_class)
      end

    end

  end

  context "monthly goal" do

    describe ".montly goal" do

      it 'returns the monthly goal' do
        PaypalOrder.monthly_goal.should == 50.0
      end

      it "is 250 for EU" do
        PaypalOrder.monthly_goal("serveme.tf").should == 250.0
      end

      it "is 175 for NA" do
        PaypalOrder.monthly_goal("na.serveme.tf").should == 175.0
      end

    end

    context "total" do

      before { time_travel_to(Date.new(2013, 11, 15)) }
      after { back_to_the_present }
      let!(:product)         { create(:product, :price => 1.0) }
      let!(:previous_month)  { create(:paypal_order, :product => product, :status => "Completed", :created_at => Time.zone.local(2013, 10, 15, 12)) }
      let!(:first_of_month)  { create(:paypal_order, :product => product, :status => "Completed", :created_at => Time.zone.local(2013, 11, 1,  12)) }
      let!(:middle_of_month) { create(:paypal_order, :product => product, :status => "Completed", :created_at => Time.zone.local(2013, 11, 15, 12)) }
      let!(:end_of_month)    { create(:paypal_order, :product => product, :status => "Completed", :created_at => Time.zone.local(2013, 11, 30, 12)) }
      let!(:next_month)      { create(:paypal_order, :product => product, :status => "Completed", :created_at => Time.zone.local(2013, 12, 1,  12)) }

      describe '.monthly' do

        it 'returns the orders for the month' do
          PaypalOrder.monthly(Time.zone.local(2013, 11, 11, 12)).should =~ [first_of_month, middle_of_month, end_of_month]
        end

      end

      describe '.monthly_total' do

        it 'returns the orders for the current month' do
          PaypalOrder.monthly_total(Time.zone.local(2013, 11, 11, 12)).should == 3.0
        end

        it 'only counts Completed orders' do
          create(:paypal_order, :status => "foobar", :product => product, :created_at => Time.zone.local(2013, 11, 15, 12))
          PaypalOrder.monthly_total(Time.zone.local(2013, 11, 11, 12)).should == 3.0
        end

      end

      describe '.monthly_goal_percentage' do

        it 'calculates the percentage of the goal achieved' do
          PaypalOrder.monthly_goal_percentage.should == 6.0
        end

      end

    end

  end


end
