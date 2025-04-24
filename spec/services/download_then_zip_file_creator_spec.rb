# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe DownloadThenZipFileCreator do
  let!(:server)        { double('Server', zip_file_creator_class: DownloadThenZipFileCreator) }
  let!(:reservation)   { double('Reservation', id: 1, server: server, status_update: nil) }

  before do
    allow(ZipUploadWorker).to receive(:perform_async)
    described_class.any_instance.stub(:strip_ips_and_api_keys_from_log_files)
  end

  describe '#create_zip' do
    it 'makes a tmpdir locally to store the files to be zipped' do
      zip_file = described_class.new(reservation, [ "foo'bar" ])
      allow(server).to receive(:copy_from_server).with(Array, String)
      allow(zip_file).to receive(:zipfile_name_and_path).and_return('/tmp/foo.zip')
      allow(zip_file).to receive(:chmod)
      expect(ZipUploadWorker).to receive(:perform_async).with(reservation.id, '/tmp/foo.zip')
      zip_file.create_zip
    end

    it 'gets the files from the server' do
      files = %w[foo bar]
      allow(server).to receive(:copy_from_server).with(files, String)
      zip_file = described_class.new(reservation, files)
      allow(zip_file).to receive(:zipfile_name_and_path).and_return('/tmp/foo.zip')
      allow(zip_file).to receive(:chmod)
      expect(ZipUploadWorker).to receive(:perform_async).with(reservation.id, '/tmp/foo.zip')
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
