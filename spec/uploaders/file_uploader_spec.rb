# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe FileUploader do
  it 'namespaces the stored zip per record so re-uploads do not overwrite each other' do
    user = create(:user, groups: [ Group.admin_group ])
    uploads = Array.new(2) do
      zip = Tempfile.new([ 'soap', '.zip' ])
      zip.write File.read(Rails.root.join('spec', 'fixtures', 'files', 'cfg.zip'))
      zip.close
      create :file_upload, file: zip, user: user
    end

    expect(File.basename(uploads.first.file.path)).to start_with("#{uploads.first.id}_")
    expect(uploads.first.file.path).not_to eq(uploads.last.file.path)
  end
end
