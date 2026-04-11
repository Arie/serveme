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

    context 'when user is config admin' do
      before do
        user.groups << Group.config_admin_group
      end

      it 'filters unauthorized files, strips disallowed commands, and skips disallowed cfg filenames' do
        cfg_file = Tempfile.new([ 'etf2l', '.cfg' ])
        cfg_file.write("exec etf2l_base\nhostname \"my server\"\nsm_updater_enabled 1\nsv_pure 2\n")
        cfg_file.close

        server_cfg_dir = Dir.mktmpdir
        server_cfg_path = File.join(server_cfg_dir, 'server.cfg')
        reservation_cfg_path = File.join(server_cfg_dir, 'reservation.cfg')
        cp_cfg_path = File.join(server_cfg_dir, 'cp_badlands.cfg')
        [ server_cfg_path, reservation_cfg_path, cp_cfg_path ].each { |f| File.write(f, '') }

        allow(file_upload).to receive(:extract_zip_to_tmp_dir).and_return({
          'cfg' => [ cfg_file.path, server_cfg_path, reservation_cfg_path, cp_cfg_path ],
          'maps' => [ '/tmp/cp_badlands.bsp' ]
        })
        expect(file_upload).to be_valid

        file_upload.save!
        allow(file_upload).to receive(:upload_files_to_servers).and_return([])
        file_upload.process_file

        expect(file_upload).to have_received(:upload_files_to_servers).with({ 'cfg' => [ cfg_file.path ] })
        expect(File.read(cfg_file.path)).to eq("exec etf2l_base\nsv_pure 2\n")
      ensure
        cfg_file&.unlink
        FileUtils.rm_rf(server_cfg_dir) if server_cfg_dir
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

  describe 'zip slip protection' do
    let(:user) { create(:user) }

    it 'skips entries with path traversal in the zip' do
      malicious_zip = Tempfile.new([ 'malicious', '.zip' ])
      Zip::OutputStream.open(malicious_zip.path) do |zos|
        zos.put_next_entry('../../etc/cron.d/evil')
        zos.write('* * * * * root echo pwned')

        zos.put_next_entry('cfg/etf2l.cfg')
        zos.write('exec etf2l_base')
      end

      file_upload = build(:file_upload, user: user)
      allow(file_upload).to receive(:file_path_for_zip).and_return(malicious_zip.path)

      tmp_dir = file_upload.tmp_dir
      result = file_upload.extract_zip_to_tmp_dir

      escaped_path = File.expand_path('../../etc/cron.d/evil', tmp_dir)
      expect(File.exist?(escaped_path)).to be false

      expect(result.keys).to eq([ 'cfg' ])
      expect(result['cfg'].length).to eq(1)
      expect(File.basename(result['cfg'].first)).to eq('etf2l.cfg')
    ensure
      malicious_zip&.unlink
    end
  end
end
