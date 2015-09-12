require 'spec_helper'

describe ServersInfoUpdaterWorker do

  it "loops over all the active servers and triggers the info updater" do
    active    = create :reservation, server: create(:server, :active => true)
    inactive  = create :reservation
    Reservation.should_receive(:current).and_return(Reservation.where(id: active.id))

    ServerInfoUpdaterWorker.should_receive(:perform_async).with(active.id)
    ServerInfoUpdaterWorker.should_not_receive(:perform_async).with(inactive.id)

    ServersInfoUpdaterWorker.perform_async
  end

end


