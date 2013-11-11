require 'spec_helper'

describe PaypalOrder do

  describe '#complete_payment!' do

    let(:order) { create(:paypal_order) }

    it "sets the status to completed" do
      order.complete_payment!
      order.status.should == "Completed"
    end

  end

  describe "#update_donator_status" do

    it "adds extra days to the donator status expiration date" do
      old_expires_at = 1.week.from_now
      number_of_days = 31
      donator_status = double(:new_record? => false, :expires_at => old_expires_at)
      subject.stub(:product => double(:days => number_of_days))
      subject.stub(:donator_status => donator_status)

      new_expires_at = old_expires_at + number_of_days.days
      donator_status.should_receive(:expires_at=).with(new_expires_at)
      donator_status.should_receive(:save)

      subject.update_donator_status
    end

  end

  describe "#update_donator_status" do

    it "adds extra days to the donator status expiration date" do
      old_expires_at = 1.week.from_now
      number_of_days = 31
      donator_status = double(:new_record? => false, :expires_at => old_expires_at)
      subject.stub(:product => double(:days => number_of_days))
      subject.stub(:donator_status => donator_status)

      new_expires_at = old_expires_at + number_of_days.days
      donator_status.should_receive(:expires_at=).with(new_expires_at)
      donator_status.should_receive(:save)

      subject.update_donator_status
    end

  end

  context "donator status" do

    it "should know a first time donator" do
      donator_status = double(:new_record? => true)
      subject.stub(:donator_status => donator_status)
      subject.should be_first_time_donator
    end

    it "should know a former donator" do
      donator_status = double(:expires_at => 1.day.ago)
      subject.stub(:donator_status => donator_status)
      subject.should be_former_donator
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

        order.prepare.should be_false
      end

      it "sets the status of the order to directed if it could create the payment" do
        payment = double(:create => true, :id => "payment_id")
        order.stub(:set_redirect_urls)
        order.stub(:add_transaction)
        order.stub(:payment => payment)

        order.prepare.should be_true
        order.status.should == "Redirected"
      end

    end

    describe "#charge" do

      let(:payment) { double }
      let(:payment_class) { double }

      before do
        payment_class.should_receive(:find).with("payment_id").and_return { payment }
        order.stub(:payment_id => "payment_id")
      end

      it "complete the payment when it was able to charge paypal" do
        payment.should_receive(:execute).with(:payer_id => "payer_id").and_return(true)

        order.should_receive(:complete_payment!)
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


end
