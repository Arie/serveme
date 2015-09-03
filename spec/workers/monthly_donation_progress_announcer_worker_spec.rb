require 'spec_helper'

describe MonthlyDonationProgressAnnouncerWorker do

  it "announces the monthly goal percentage to all non-donators once per day" do
    non_donator = create :user
    donator = create :user, groups: [Group.donator_group]
    server = build :server
    non_donator_reservation = build :reservation, :server => server, :user => non_donator
    donator_server = build :server
    donator_reservation = build :reservation, :server => donator_server, :user => donator

    human_date = Date.today.strftime("%B %-d")

    mock_reservation_class = double(:reservations, :current => [non_donator_reservation, donator_reservation])
    Reservation.should_receive(:includes).with(:user, :server).and_return(mock_reservation_class)

    expect(server).to receive(:rcon_say).with("Today is #{human_date}, this month's donations have paid for 0 percent of our server bills. Please donate at #{SITE_HOST} to keep this service alive")
    expect(donator_server).not_to receive(:rcon_say)

    MonthlyDonationProgressAnnouncerWorker.perform_async
  end

end
