require 'spec_helper'

describe RemoteLogCopier do

  describe '#copy_logs' do

    it "tells the server which logs to copy and where to them to" do
      logs = double
      server = double(:logs => logs)
      reservation = double(:id => 1, :zipfile_name => "foo.zip")

      destination = "dir"
      log_copier = RemoteLogCopier.new(reservation, server)
      log_copier.stub(:directory_to_copy_to => destination)

      log_copier.should_receive("system").with("unzip #{Rails.root.join("public", "uploads", "foo.zip")} *.log -d dir")

      log_copier.copy_logs
    end

  end

end
