# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe UploadFilesToServerWorker do
  it 'looks over the supplied files and uploads' do
    allow(FileUpload).to receive(:new).and_wrap_original do |method, *args, **kwargs|
      instance = method.call(*args, **kwargs)
      allow(instance).to receive(:validate_file_permissions)
      instance
    end
    file_upload = create(:file_upload)
    server_upload = create(:server_upload, file_upload: file_upload)
    server = server_upload.server
    files_with_path = {
      'cfg' => [ '/tmp/foo.cfg', '/tmp/item_whitelist.txt' ],
      'maps' => [ '/tmp/foo.bsp', '/tmp/bar.bsp' ]
    }

    allow(Server).to receive(:find).with(server.id).and_return(server)
    allow(server).to receive(:copy_to_server)

    described_class.perform_async('server_upload_id' => server_upload.id, 'files_with_path' => files_with_path)

    expect(server).to have_received(:copy_to_server).with([ '/tmp/foo.cfg', '/tmp/item_whitelist.txt' ], File.join(server.tf_dir, 'cfg'))
    expect(server).to have_received(:copy_to_server).with([ '/tmp/foo.bsp', '/tmp/bar.bsp' ], File.join(server.tf_dir, 'maps'))
  end
end
