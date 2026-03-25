# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe RemoteLogCopier do
  describe '#copy_logs' do
    it 'extracts log files from the zip to the destination directory' do
      logs = double
      server = double(logs: logs)
      reservation = double(id: 1, zipfile_name: 'foo.zip')

      destination = Dir.mktmpdir
      log_copier = RemoteLogCopier.new(reservation, server)
      log_copier.stub(directory_to_copy_to: destination)

      zipfile_path = Rails.root.join('public', 'uploads', 'foo.zip').to_s

      Zip::File.open(zipfile_path, create: true) do |zip|
        zip.get_output_stream("test.log") { |f| f.write("log content") }
        zip.get_output_stream("demo.dem") { |f| f.write("demo content") }
      end

      log_copier.copy_logs

      expect(File.exist?(File.join(destination, "test.log"))).to be true
      expect(File.exist?(File.join(destination, "demo.dem"))).to be false
      expect(File.read(File.join(destination, "test.log"))).to eq("log content")
    ensure
      FileUtils.rm_rf(destination)
      FileUtils.rm_f(zipfile_path)
    end

    it 'does nothing when the zip file does not exist' do
      logs = double
      server = double(logs: logs)
      reservation = double(id: 1, zipfile_name: 'nonexistent.zip')

      log_copier = RemoteLogCopier.new(reservation, server)
      log_copier.stub(directory_to_copy_to: '/tmp')

      expect { log_copier.copy_logs }.not_to raise_error
    end
  end
end
