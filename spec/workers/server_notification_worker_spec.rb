require 'spec_helper'

describe ServerNotificationWorker do

  let(:reservation)   { create :reservation, :starts_at => 10.minutes.ago, :ends_at => 1.hour.from_now, :provisioned => true }
  let(:non_donator)   { create :user }
  let(:donator)       { create :user, :groups => [Group.donator_group] }
  let(:server)        { double(:server, :set_logaddress => true) }

  before do
    Reservation.should_receive(:includes).with(:user, :server).and_return(Reservation)
    Reservation.should_receive(:current).and_return([reservation])
    reservation.stub(:server => server)
  end

  describe "#send_notification" do

    context "even without notifications" do

      it "sets the logaddress, just in case it was deleted" do
        server.should_receive(:set_logaddress)
        ServerNotificationWorker.perform_async
      end

    end

    context "with notifications" do

      before do
        create :server_notification, notification_type: 'ad', message: "this is an ad"
      end


      it "can send an ad to non donators" do
        reservation.stub(:user => non_donator)
        server.should_receive(:rcon_say).with("this is an ad")
        ServerNotificationWorker.perform_async
      end

      it "can send a donator notifications to donators" do
        create :server_notification, notification_type: "donator", message: "thanks for donating"
        reservation.stub(:user => donator)
        server.should_receive(:rcon_say).with("thanks for donating")
        ServerNotificationWorker.perform_async
      end

      it "wont send an ad to donators" do
        create :server_notification, notification_type: "ad", message: "this is a notification"
        reservation.stub(:user => donator)
        server.should_not_receive(:rcon_say).with("this is an ad")
        ServerNotificationWorker.perform_async
      end

      it "can use the user's name as a variable" do
        create :server_notification, notification_type: "donator", message: "thanks for donating %{name}, you rock!"
        donator.stub(:nickname => "Arie")
        reservation.stub(:user => donator)
        server.should_receive(:rcon_say).with("thanks for donating Arie, you rock!")
        ServerNotificationWorker.perform_async
      end

    end

  end
end

