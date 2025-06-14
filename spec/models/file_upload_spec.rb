# typed: false
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

        source = File.open(Rails.root.join('spec', 'fixtures', 'files', 'cfg.zip'))
        zip = Tempfile.new([ 'foo', '.zip' ])
        zip.write source.read
        zip.close

        allow(UploadFilesToServerWorker).to receive(:perform_async)
        user = create(:user)
        user.create_file_upload_permission(allowed_paths: [ 'cfg/' ])

        file_upload = create :file_upload, file: zip, user: user
        file_upload.process_file

        cfgs_with_paths = { 'cfg' => [ File.join(file_upload.tmp_dir, 'cfg/etf2l.cfg').to_s, File.join(file_upload.tmp_dir, 'cfg/etf2l_custom.cfg').to_s, File.join(file_upload.tmp_dir, 'cfg/etf2l_whitelist_6v6.txt').to_s ] }

        expect(UploadFilesToServerWorker).to have_received(:perform_async).with('server_upload_id' => anything, 'files_with_path' => cfgs_with_paths)
      end
    end
  end

  let(:user) { create(:user) }
  let(:file_upload) { build(:file_upload, user: user) }

  describe 'file permission validation' do
    context 'when user is admin' do
      before do
        user.groups << Group.admin_group
      end

      it 'allows any file path' do
        allow(file_upload).to receive(:extract_zip_to_tmp_dir).and_return({
          'addons/sourcemod/configs' => [ '/tmp/mgemod_spawns.cfg' ],
          'maps' => [ '/tmp/cp_badlands.bsp' ]
        })
        expect(file_upload).to be_valid
      end
    end

    context 'when user has file upload permission' do
      before do
        user.create_file_upload_permission(allowed_paths: [ 'addons/sourcemod/configs/' ])
      end

      it 'allows files in permitted paths' do
        allow(file_upload).to receive(:extract_zip_to_tmp_dir).and_return({
          'addons/sourcemod/configs' => [ '/tmp/mgemod_spawns.cfg' ]
        })
        expect(file_upload).to be_valid
      end

      it 'denies files outside permitted paths' do
        allow(file_upload).to receive(:extract_zip_to_tmp_dir).and_return({
          'maps' => [ '/tmp/cp_badlands.bsp' ]
        })
        expect(file_upload).not_to be_valid
        expect(file_upload.errors[:file]).to include('contains files in unauthorized path: maps')
      end

      it 'denies mixed permitted and non-permitted paths' do
        allow(file_upload).to receive(:extract_zip_to_tmp_dir).and_return({
          'addons/sourcemod/configs' => [ '/tmp/mgemod_spawns.cfg' ],
          'maps' => [ '/tmp/cp_badlands.bsp' ]
        })
        expect(file_upload).not_to be_valid
        expect(file_upload.errors[:file]).to include('contains files in unauthorized path: maps')
      end
    end

    context 'when user has no file upload permission' do
      it 'denies all files' do
        allow(file_upload).to receive(:extract_zip_to_tmp_dir).and_return({
          'addons/sourcemod/configs' => [ '/tmp/mgemod_spawns.cfg' ]
        })
        expect(file_upload).not_to be_valid
        expect(file_upload.errors[:file]).to include('contains files in unauthorized path: addons/sourcemod/configs')
      end
    end

    context 'when user has specific file upload permission' do
      before do
        user.create_file_upload_permission(allowed_paths: [ 'addons/sourcemod/configs/mgemod_spawns.cfg' ])
      end

      it 'allows files in permitted paths' do
        allow(file_upload).to receive(:extract_zip_to_tmp_dir).and_return({
          'addons/sourcemod/configs' => [ '/tmp/mgemod_spawns.cfg' ]
        })
        expect(file_upload).to be_valid
      end

      it 'denies files outside permitted paths' do
        allow(file_upload).to receive(:extract_zip_to_tmp_dir).and_return({
          'maps' => [ '/tmp/cp_badlands.bsp' ]
        })
        expect(file_upload).not_to be_valid
        expect(file_upload.errors[:file]).to include('contains files in unauthorized path: maps')
      end
    end
  end

  describe 'archives zip' do
    let(:zip) { fixture_file_upload('spec/fixtures/files/spawns.zip', 'application/zip') }
    let(:user) { create(:user) }

    context 'user has permission for only addons/sourcemod/configs/' do
      before do
        user.create_file_upload_permission(allowed_paths: [ 'addons/sourcemod/configs/' ])
      end

      it 'allows upload for addons/sourcemod/configs/' do
        file_upload = build :file_upload, file: zip, user: user
        expect(file_upload).to be_valid
      end
    end
  end
end
