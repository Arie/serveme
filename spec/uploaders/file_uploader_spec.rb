# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe FileUploader do
  # UploadFilesToServerWorker re-reads the stored zip in another process, so a
  # reloaded record's file.path must point at a file that is actually there.
  it 'stores the zip where a reloaded record says it is' do
    user = create(:user, groups: [ Group.admin_group ])
    tmp = Tempfile.new([ 'upload', '.zip' ], binmode: true)
    tmp.write File.read(Rails.root.join('spec', 'fixtures', 'files', 'cfg.zip'))
    tmp.rewind

    file_upload = FileUpload.new(user: user)
    file_upload.file = tmp
    file_upload.save!

    reloaded = FileUpload.find(file_upload.id)
    expect(reloaded.file.path).to be_present
    expect(File.exist?(reloaded.file.path)).to be true
  end
end
