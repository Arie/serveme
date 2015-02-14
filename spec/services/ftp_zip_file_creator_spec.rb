require 'spec_helper'

describe FtpZipFileCreator do

  let!(:server)        { double(:zip_file_creator_class => FtpZipFileCreator) }
  let!(:reservation)   { double(:server => server, :status_update => nil) }

  describe '#create_zip' do

    it "makes a tmpdir locally to store the files to be zipped" do
      Dir.should_receive(:mktmpdir)
      zip_file = FtpZipFileCreator.new(reservation, ["foo'bar"])
      zip_file.stub(:zipfile_name => "/tmp/foo.zip")
      zip_file.should_receive(:chmod)
      zip_file.create_zip
    end

    it "gets the files from the server" do
      tmp_dir = "tmp_dir"
      Dir.should_receive(:mktmpdir).and_yield(tmp_dir)
      files = ['foo', 'bar']
      server.should_receive(:copy_from_server).with(files, tmp_dir)
      zip_file = FtpZipFileCreator.new(reservation, files)
      zip_file.stub(:zipfile_name => "/tmp/foo.zip")
      zip_file.create_zip
    end
  end

  describe '#zip' do

    it 'zips the file in the tmp dir' do
      zip_file_stub = double
      files = ['/tmp/foo']
      tmp_dir = "tmp_dir"
      zipfile_name_and_path = '/tmp/foo.zip'

      zip_file_stub.should_receive(:add).with(File.basename(files.first), files.first)
      zip_file = FtpZipFileCreator.new(reservation, files)
      zip_file.should_receive(:files_to_zip_in_dir).with(tmp_dir).and_return(files)
      zip_file.stub(:zipfile_name_and_path => zipfile_name_and_path)
      Zip::File.should_receive(:open).with(zipfile_name_and_path, Zip::File::CREATE).and_yield(zip_file_stub)
      zip_file.zip(tmp_dir)
    end
  end

end

