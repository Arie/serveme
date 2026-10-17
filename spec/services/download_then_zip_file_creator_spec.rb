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
    it 'removes IPs, API keys and the logsecret from log files' do
      Dir.mktmpdir do |dir|
        log = File.join(dir, 'a.log')
        File.binwrite(log, %(L 10/17/2026 - 12:00:00: "p\xff<2><[U:1:1]><>" connected, address "1.2.3.4:27005"\n) +
                           %(rcon from "5.6.7.8:1": command "sv_logsecret 123456; logstf_apikey "abc def"; sm_demostf_apikey "x+y/z=""\n))
        demo = File.join(dir, 'a.dem')
        File.write(demo, '1.2.3.4')

        zip_file = described_class.new(reservation, [])
        allow(zip_file).to receive(:strip_ips_and_api_keys_from_log_files).and_call_original
        zip_file.strip_ips_and_api_keys_from_log_files(dir)

        stripped = File.binread(log)
        expect(stripped).not_to include('1.2.3.4', '5.6.7.8', '123456', 'abc def', 'x+y/z=')
        expect(stripped).to include('logstf_apikey "apikey"', 'sm_demostf_apikey "apikey"', "p\xff".b)
        expect(File.read(demo)).to eq('1.2.3.4')
      end
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
