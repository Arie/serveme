require 'spec_helper'

describe SshZipFileCreator do

  let!(:server)        { double(:zip_file_creator_class => SshZipFileCreator, :name => "The server") }
  let!(:reservation)   { double(:server => server, :status_update => nil) }

  it "shell escapes the file names" do
    zip_file = SshZipFileCreator.new(reservation, ["foo'bar"])
    zip_file.stub(:remote_zip_name => "foo.zip")
    server.should_receive(:execute).with("zip -j foo.zip foo\\'bar")
    zip_file.zip
  end

  describe '#create_zip' do

    it "zips, downloads the zip, remove the zip from the server and chmods the file" do
      zip_file = SshZipFileCreator.new(reservation, ["foo'bar"])
      zip_file.should_receive(:zip)
      zip_file.should_receive(:download_zip_from_remote_server)
      zip_file.should_receive(:remove_zip_file_on_remote_server)
      zip_file.should_receive(:chmod)
      zip_file.create_zip
    end

  end

  describe '#download_zip_from_remote_server' do

    it 'tells the server to download' do
      zip_file = SshZipFileCreator.new(reservation, ["foo'bar"])
      zip_file.stub(:server => server)
      zip_file.stub(:remote_zip_name => 'foo.zip')
      zip_file.stub(:zipfile_name_and_path => 'bar.zip')
      server.should_receive(:copy_from_server).with([zip_file.remote_zip_name], zip_file.zipfile_name_and_path)
      zip_file.download_zip_from_remote_server
    end
  end

  describe '#remote_zip_name' do

    it 'generates the remote zip name from the servers tf dir and reservations id' do
      zip_file = SshZipFileCreator.new(reservation, ["foo'bar"])
      zip_file.stub(:server => server)
      reservation.stub(:id => 1337)
      server.stub(:tf_dir => "foo")
      zip_file.remote_zip_name.should == "#{server.tf_dir}/logs_and_demos_#{zip_file.reservation.id}.zip"
    end
  end

  describe '#remove_zip_file_on_remote_server' do

    it 'removes the remote zip file' do
      zip_file = SshZipFileCreator.new(reservation, ["foo'bar"])
      zip_file.stub(:server => server)
      zip_file.stub(:remote_zip_name => "foo.zip")
      server.should_receive(:execute).with("rm foo.zip")
      zip_file.remove_zip_file_on_remote_server
    end
  end

end
