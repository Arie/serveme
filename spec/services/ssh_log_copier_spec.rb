require 'spec_helper'

describe SshLogCopier do

  describe '#copy_logs' do

    it "tells the server which logs to copy and where to them to" do
      logs = double
      server = double(:logs => logs)
      reservation = double(:id => 1, :zipfile_name => "foo.zip")

      destination = double
      log_copier = SshLogCopier.new(reservation, server)
      log_copier.stub(:directory_to_copy_to => destination)

      zipped_file = double(:name => "foo.log")
      Zip::ZipFile.should_receive(:foreach).with(Rails.root.join("public", "uploads", reservation.zipfile_name)).and_yield(zipped_file)
      zipped_file.should_receive(:extract).with("#{destination}/#{zipped_file.name}")

      log_copier.copy_logs
    end

  end

end
