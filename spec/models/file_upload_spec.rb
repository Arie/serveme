# frozen_string_literal: true

require 'spec_helper'

describe FileUpload do
  it 'requires a user' do
    subject.valid?
    subject.should have(1).error_on(:user_id)
  end

  context 'archives', :map_archive do
    context 'zip' do
      it 'sends the files to the servers' do
        create(:server)

        source = File.open(Rails.root.join('spec', 'fixtures', 'cfg.zip'))
        zip = Tempfile.new(['foo', '.zip'])
        zip.write source.read
        zip.close

        allow(UploadFilesToServerWorker).to receive(:perform_async)

        file_upload = create :file_upload, file: zip
        file_upload.process_file

        cfgs_with_paths = { 'cfg' => [File.join(file_upload.tmp_dir, 'cfg/etf2l.cfg').to_s, File.join(file_upload.tmp_dir, 'cfg/etf2l_custom.cfg').to_s, File.join(file_upload.tmp_dir, 'cfg/etf2l_whitelist_6v6.txt').to_s] }

        expect(UploadFilesToServerWorker).to have_received(:perform_async).with(server_upload_id: anything, files_with_path: cfgs_with_paths)
      end
    end
  end
end
