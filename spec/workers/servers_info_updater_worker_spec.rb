require 'spec_helper'

describe ServersInfoUpdaterWorker do

  it "loops over all the active servers and triggers the info updater" do
    active    = create :server, :active => true
    inactive  = create :server, :active => false

    ServerInfoUpdaterWorker.should_receive(:perform_async).with(active.id)
    ServerInfoUpdaterWorker.should_not_receive(:perform_async).with(inactive.id)

    ServersInfoUpdaterWorker.perform_async
  end

end


