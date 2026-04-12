# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe DownloadThenZipFileCreator do
  let(:server)        { double('Server', zip_file_creator_class: DownloadThenZipFileCreator) }
  let(:reservation)   { double('Reservation', id: 1, server: server, status_update: nil) }

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
      zip_file.create_zip
    end

    it 'gets the files from the server' do
      files = %w[foo bar]
      allow(server).to receive(:copy_from_server).with(files, String)
      zip_file = described_class.new(reservation, files)
      allow(zip_file).to receive(:zipfile_name_and_path).and_return('/tmp/foo.zip')
      allow(zip_file).to receive(:chmod)
      zip_file.create_zip
    end
  end

  describe '#strip_ips_and_api_keys_from_log_files' do
    it 'uses array form system call to avoid shell injection' do
      zip_file = described_class.new(reservation, [])
      allow(zip_file).to receive(:strip_ips_and_api_keys_from_log_files).and_call_original
      allow(Dir).to receive(:glob).with("/tmp/some_dir/*.log").and_return([ "/tmp/some_dir/a.log", "/tmp/some_dir/b.log" ])

      expect(Open3).to receive(:capture3).with(
        { "LANG" => "ALL", "LC_ALL" => "C" },
        "sed", "-i", "-r",
        's/(\b[0-9]{1,3}\.){3}[0-9]{1,3}\b/0.0.0.0/g;s/logstf_apikey \"\S+\"/logstf_apikey \"apikey\"/g;s/tftrue_logs_apikey \"\S+\"/tftrue_logs_apikey \"apikey\"/g;s/sm_demostf_apikey \"\S+\"/sm_demostf_apikey \"apikey\"/g',
        "/tmp/some_dir/a.log", "/tmp/some_dir/b.log"
      ).and_return([ "", "", double(success?: true) ])

      zip_file.strip_ips_and_api_keys_from_log_files("/tmp/some_dir")
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
      Zip::File.should_receive(:open).with(zipfile_name_and_path, create: true).and_yield(zip_file_stub)
      zip_file.zip(tmp_dir)
    end
  end
end
