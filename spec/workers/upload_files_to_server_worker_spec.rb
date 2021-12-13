# frozen_string_literal: true

require 'spec_helper'

describe UploadFilesToServerWorker do
  it 'looks over the supplied files and uploads' do
    server_upload = create :server_upload
    server = server_upload.server
    files_with_path = {
      'cfg' => ['foo.cfg', 'item_whitelist.txt'],
      'maps' => ['foo.bsp', 'bar.bsp']
    }

    allow(Server).to receive(:find).with(server.id).and_return(server)
    allow(server).to receive(:copy_to_server)

    described_class.perform_async(server_upload_id: server_upload.id, files_with_path: files_with_path)

    expect(server).to have_received(:copy_to_server).with(['foo.cfg', 'item_whitelist.txt'], File.join(server.tf_dir, 'cfg'))
    expect(server).to have_received(:copy_to_server).with(['foo.bsp', 'bar.bsp'], File.join(server.tf_dir, 'maps'))
  end
end
