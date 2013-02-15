require 'spec_helper'

describe SshLogCopier do

  describe '#copy_logs' do

    it "tells the server which logs to copy and where to them to" do
      logs = stub
      server = stub(:logs => logs)

      destination = stub
      log_copier = SshLogCopier.new(1, server)
      log_copier.stub(:directory_to_copy_to => destination)

      server.should_receive(:copy_from_server).with(logs, destination)
      log_copier.copy_logs
    end

  end

end
