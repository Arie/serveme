# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe UploadFilesToServerWorker do
  let(:file_upload) { create(:file_upload) }
  let(:server_upload) { create(:server_upload, file_upload: file_upload) }
  let(:server) { server_upload.server }
  let(:files_with_path) { { 'cfg' => [ '/tmp/foo.cfg' ] } }
  let(:copy_result) { true }

  before do
    allow(FileUpload).to receive(:new).and_wrap_original do |method, *args, **kwargs|
      instance = method.call(*args, **kwargs)
      allow(instance).to receive(:validate_file_permissions)
      instance
    end
    allow(ServerUpload).to receive(:find_by).with(id: server_upload.id).and_return(server_upload)
    allow(server_upload).to receive(:file_upload).and_return(file_upload)
    allow(file_upload).to receive(:files_to_upload).and_return(files_with_path)
    allow(Server).to receive(:find).with(server.id).and_return(server)
    allow(server).to receive(:copy_to_server).and_return(copy_result)
  end

  context 'with files in several destinations' do
    let(:files_with_path) do
      {
        'cfg' => [ '/tmp/foo.cfg', '/tmp/item_whitelist.txt' ],
        'maps' => [ '/tmp/foo.bsp', '/tmp/bar.bsp' ]
      }
    end

    it 'extracts the zip itself instead of trusting paths from another process' do
      described_class.perform_async('server_upload_id' => server_upload.id)

      expect(file_upload).to have_received(:files_to_upload)
      expect(server).to have_received(:copy_to_server).with([ '/tmp/foo.cfg', '/tmp/item_whitelist.txt' ], File.join(server.tf_dir, 'cfg'))
      expect(server).to have_received(:copy_to_server).with([ '/tmp/foo.bsp', '/tmp/bar.bsp' ], File.join(server.tf_dir, 'maps'))
      expect(server_upload.uploaded_at).to be_present
    end
  end

  context 'with a path traversal attempt' do
    let(:files_with_path) do
      {
        '../../etc/cron.d' => [ '/tmp/evil.cfg' ],
        'cfg' => [ '/tmp/foo.cfg' ]
      }
    end

    it 'skips the escaping destination' do
      described_class.perform_async('server_upload_id' => server_upload.id)

      expect(server).not_to have_received(:copy_to_server).with([ '/tmp/evil.cfg' ], anything)
      expect(server).to have_received(:copy_to_server).with([ '/tmp/foo.cfg' ], File.join(server.tf_dir, 'cfg'))
    end
  end

  context 'when the copy fails' do
    let(:copy_result) { false }

    it 'raises and leaves the upload unfinished' do
      expect { described_class.new.perform('server_upload_id' => server_upload.id) }.to raise_error(described_class::UploadFailedError)
      expect(server_upload.uploaded_at).to be_nil
    end
  end

  it 'cleans up the extracted files afterwards' do
    allow(file_upload).to receive(:cleanup_tmp_dir)

    described_class.perform_async('server_upload_id' => server_upload.id)

    expect(file_upload).to have_received(:cleanup_tmp_dir)
  end
end
