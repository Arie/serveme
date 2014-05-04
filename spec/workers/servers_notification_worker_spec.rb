require 'spec_helper'

describe ServerNotificationWorker do

  let(:reservation)   { create :reservation, :starts_at => 10.minutes.ago, :ends_at => 1.hour.from_now, :provisioned => true }

  it "sends the current reservations to the server notification worker" do
    ServerNotificationWorker.should_receive(:perform_async).with(reservation.id)
    ServersNotificationWorker.perform_async
  end

end

