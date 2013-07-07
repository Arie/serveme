require 'zip/zip'
require 'spec_helper'

describe ZipFileCreator do

  let!(:zipper_class)  { LocalZipFileCreator }
  let!(:server)        { double(:zip_file_creator_class => zipper_class) }
  let!(:reservation)   { double(:server => server) }
  let!(:files_to_zip)  { double }

  describe '.create' do

    it "instantiates the correct ZipFileCreator based on the server and creates the zip" do
      created_zipper = double
      created_zipper.should_receive(:create_zip)
      zipper_class.should_receive(:new).with(reservation, files_to_zip).and_return { created_zipper }
      ZipFileCreator.create(reservation, files_to_zip)
    end

  end

  describe '#chmod' do


    it 'chmods the zipfile' do
      reservation = double(:zipfile_name => 'destination_file.zip', :server => server)
      File.should_receive(:chmod).with(0755, Rails.root.join('public', 'uploads', 'destination_file.zip'))
      LocalZipFileCreator.any_instance.stub(:zip)

      ZipFileCreator.create(reservation, files_to_zip)
    end
  end

  describe LocalZipFileCreator do

    describe '#zip' do

      it "it adds the files to zip to a zipfile" do
        zip_file = LocalZipFileCreator.new(reservation, ["foo'bar"])
        zip_file.stub(:server => server)
        zip_file.stub(:files_to_zip => ['foo/qux.zip'])
        zip_file.stub(:zipfile_name_and_path => 'bar.zip')
        zip_zip_file = double
        Zip::ZipFile.should_receive(:open).with(zip_file.zipfile_name_and_path, Zip::ZipFile::CREATE).and_yield(zip_zip_file)
        zip_zip_file.should_receive(:add).with('qux.zip', 'foo/qux.zip')
        zip_file.zip
      end

    end
  end

  describe SshZipFileCreator do

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

end
