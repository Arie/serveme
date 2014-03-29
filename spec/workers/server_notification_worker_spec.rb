require 'spec_helper'

describe ServerNotificationWorker do

  let(:reservation)   { create :reservation, :starts_at => 10.minutes.ago, :ends_at => 1.hour.from_now, :provisioned => true }
  let(:non_donator)   { create :user }
  let(:donator)       { create :user, :groups => [Group.donator_group] }
  let(:server)        { double :server }

  before do
    Reservation.should_receive(:includes).with(:user, :server).and_return(Reservation)
    Reservation.should_receive(:current).and_return([reservation])
    reservation.stub(:server => server)
  end

  describe "#send_notification" do

    before do
      create :server_notification, :ad => true, :message => "this is an ad"
    end

    it "can send an ad to non donators" do
      reservation.stub(:user => non_donator)
      server.should_receive(:rcon_say).with("this is an ad")
      ServerNotificationWorker.perform_async
    end

    it "wont send an add to donators" do
      create :server_notification, :ad => true, :message => "this is a notification"
      reservation.stub(:user => donator)
      server.should_not_receive(:rcon_say).with("this is an ad")
      ServerNotificationWorker.perform_async
    end

  end
end

