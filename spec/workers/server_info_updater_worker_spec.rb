require 'spec_helper'

describe ServerInfoUpdaterWorker do

  it "gets the server info" do
    server    = create :server

    Server.should_receive(:find).with(server.id).and_return { server }

    server_info = double(:server_info)
    ServerInfo.should_receive(:new).with(server).and_return { server_info }

    server_info.should_receive(:status)
    server_info.should_receive(:get_stats)
    ServerInfoUpdaterWorker.perform_async(server.id)
  end

end


