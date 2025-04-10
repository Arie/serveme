# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe DownloadThenZipFileCreator do
  let!(:server)        { double(zip_file_creator_class: DownloadThenZipFileCreator) }
  let!(:reservation)   { double(server: server, status_update: nil) }

  before do
    described_class.any_instance.stub(:strip_ips_and_api_keys_from_log_files)
  end

  describe '#create_zip' do
    it 'makes a tmpdir locally to store the files to be zipped' do
      zip_file = described_class.new(reservation, [ "foo'bar" ])
      server.should_receive(:copy_from_server).with(Array, String)
      zip_file.stub(zipfile_name: '/tmp/foo.zip')
      zip_file.should_receive(:chmod)
      zip_file.create_zip
    end

    it 'gets the files from the server' do
      files = %w[foo bar]
      server.should_receive(:copy_from_server).with(files, String)
      zip_file = described_class.new(reservation, files)
      zip_file.stub(zipfile_name: '/tmp/foo.zip')
      zip_file.create_zip
    end
  end

  describe '#zip' do
    it 'zips the file in the tmp dir' do
      zip_file_stub = double
      files = [ '/tmp/foo' ]
      tmp_dir = 'tmp_dir'
      zipfile_name_and_path = '/tmp/foo.zip'

      zip_file_stub.should_receive(:add).with(File.basename(files.first), files.first)
      zip_file = described_class.new(reservation, files)
      zip_file.should_receive(:files_to_zip_in_dir).with(tmp_dir).and_return(files)
      zip_file.stub(zipfile_name_and_path: zipfile_name_and_path)
      Zip::File.should_receive(:open).with(zipfile_name_and_path, Zip::File::CREATE).and_yield(zip_file_stub)
      zip_file.zip(tmp_dir)
    end
  end
end
