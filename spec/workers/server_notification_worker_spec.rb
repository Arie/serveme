require 'spec_helper'

describe ServerNotificationWorker do

  let(:reservation)   { create :reservation, :starts_at => 10.minutes.ago, :ends_at => 1.hour.from_now, :provisioned => true }
  let(:non_donator)   { create :user }
  let(:donator)       { create :user, :groups => [Group.donator_group] }
  let(:server)        { double(:server) }

  before do
    reservation.stub(:server => server)
    Reservation.should_receive(:includes).with(:user, :server).and_return(Reservation)
    Reservation.should_receive(:find).with(reservation.id).and_return(reservation)
  end

  describe "#send_notification" do

    before do
      create :server_notification, notification_type: 'ad', message: "this is an ad"
    end


    it "can send an ad to non donators" do
      reservation.stub(:user => non_donator)
      server.should_receive(:rcon_say).with("this is an ad")
      ServerNotificationWorker.perform_async(reservation.id)
    end

    it "can send a donator notifications to donators" do
      create :server_notification, notification_type: "donator", message: "thanks for donating"
      reservation.stub(:user => donator)
      server.should_receive(:rcon_say).with("thanks for donating")
      ServerNotificationWorker.perform_async(reservation.id)
    end

    it "wont send an ad to donators" do
      create :server_notification, notification_type: "ad", message: "this is a notification"
      reservation.stub(:user => donator)
      server.should_not_receive(:rcon_say).with("this is an ad")
      ServerNotificationWorker.perform_async(reservation.id)
    end

    it "can use the user's name as a variable" do
      create :server_notification, notification_type: "donator", message: "thanks for donating %{name}, you rock!"
      donator.stub(:nickname => "Arie")
      reservation.stub(:user => donator)
      server.should_receive(:rcon_say).with("thanks for donating Arie, you rock!")
      ServerNotificationWorker.perform_async(reservation.id)
    end

  end
end

