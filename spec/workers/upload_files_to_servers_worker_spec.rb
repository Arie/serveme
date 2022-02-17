# frozen_string_literal: true

require 'spec_helper'

describe UploadFilesToServersWorker do
  context 'when not overwriting' do
    it 'loops over all the active servers and uploads missing files' do
      server = create :server, active: true
      files = %w[foo bar]
      existing_files = ['foo']
      destination = 'tmp'

      UploadFilesToServersWorker.should_receive(:servers).and_return([server])
      server.should_receive(:list_files).with(destination).and_return(existing_files)
      server.should_receive(:copy_to_server).with(['bar'], File.join(server.tf_dir, destination))

      UploadFilesToServersWorker.perform_async('files' => files, 'destination' => destination, 'overwrite' => false)
    end
  end

  context 'when overwriting' do
    it 'loops over all the active servers and uploads all files' do
      server = create :server, active: true
      files = %w[foo bar]
      destination = 'tmp'

      UploadFilesToServersWorker.should_receive(:servers).and_return([server])
      server.should_receive(:copy_to_server).with(files, File.join(server.tf_dir, destination))

      UploadFilesToServersWorker.perform_async('files' => files, 'destination' => destination, 'overwrite' => true)
    end
  end
end
