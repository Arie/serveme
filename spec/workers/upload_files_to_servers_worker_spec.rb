require 'spec_helper'

describe UploadFilesToServersWorker do

  context "when not overwriting" do
    it "loops over all the active servers and uploads missing files" do
      server = create :server, :active => true
      files = ["foo", "bar"]
      existing_files = ["foo"]
      destination = "tmp"

      Server.should_receive(:active).and_return([server])
      server.should_receive(:list_files).with(destination).and_return(existing_files)
      server.should_receive(:copy_to_server).with(["bar"], File.join(server.game_dir, destination))

      UploadFilesToServersWorker.perform_async('files' => files, 'destination' => destination, 'overwrite' => false)
    end
  end

  context "when overwriting" do

    it "loops over all the active servers and uploads all files" do
      server = create :server, :active => true
      files = ["foo", "bar"]
      destination = "tmp"

      Server.should_receive(:active).and_return([server])
      server.should_receive(:copy_to_server).with(files, File.join(server.game_dir, destination))

      UploadFilesToServersWorker.perform_async('files' => files, 'destination' => destination, 'overwrite' => true)
    end

  end

end


