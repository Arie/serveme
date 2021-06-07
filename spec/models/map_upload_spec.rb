# frozen_string_literal: true

require 'spec_helper'

describe MapUpload do
  it 'requires a user' do
    subject.valid?
    subject.should have(1).error_on(:user_id)
  end

  it 'fails on a bad map file' do
    bad_map = Tempfile.new(['foo', '.bsp'])
    bad_map.write 'foobar'
    bad_map.close
    upload = build :map_upload, file: bad_map
    upload.valid?
    expect(upload.errors.full_messages).to include('File not a map (bsp) file')
  end

  it 'rejects blacklisted (crashing) maps' do
    file = double(:file, filename: 'pl_badwater_pro_v8.bsp')
    subject.stub(file: file)
    subject.validate_not_blacklisted
    subject.errors.full_messages.should == ['File map blacklisted, causes server instability']
  end

  it 'rejects blacklisted game types' do
    filenames = [
      'trade_foobarwidget.bsp',
      'vsh_foobarwidget.bsp',
      'mvm_foobarwidget.bsp',
      'jail_foobarwidget.bsp',
      'achievement_foobarwidget.bsp',
      'TRADE_foobarwidget.bsp',
      'VSH_foobarwidget.bsp',
      'MVM_foobarwidget.bsp',
      'JAIL_foobarwidget.bsp',
      'ACHIEVEMENT_foobarwidget.bsp'
    ]
    filenames.each do |filename|
      file = double(:file, filename: filename)
      map_upload = described_class.new
      map_upload.stub(file: file)
      map_upload.validate_not_blacklisted_type
      map_upload.errors.full_messages.should == ['File game type not allowed']
    end
  end

  context 'archives', :map_archive do
    context 'zip' do
      it 'extracts the zip when uploading a zip' do
        source = File.open(Rails.root.join('spec', 'fixtures', 'maps.zip'))
        zip = Tempfile.new(['foo', '.zip'])
        zip.write source.read
        zip.close

        create :map_upload, file: zip

        maps_with_path = Dir.glob(File.join(MAPS_DIR, '*.bsp'))
        maps = maps_with_path.map { |file| File.basename(file) }
        expect(maps).to include 'achievement_idle.bsp', 'achievement_idle_foo.bsp'
      end

      it 'sends the files to the servers' do
        source = File.open(Rails.root.join('spec', 'fixtures', 'maps.zip'))
        zip = Tempfile.new(['foo', '.zip'])
        zip.write source.read
        zip.close

        allow(UploadFilesToServersWorker).to receive(:perform_async)

        create :map_upload, file: zip

        maps_with_paths = [Rails.root.join('tmp', 'achievement_idle.bsp').to_s, Rails.root.join('tmp', 'achievement_idle_foo.bsp').to_s]

        expect(UploadFilesToServersWorker).to have_received(:perform_async).with(files: maps_with_paths,
                                                                                 destination: 'maps',
                                                                                 overwrite: false)
      end
    end

    context 'bz2' do
      it 'extracts the bz2 when uploading a bz2' do
        source = File.open(Rails.root.join('spec', 'fixtures', 'achievement_idle.bsp.bz2'))
        FileUtils.cp(source, Rails.root.join('spec', 'fixtures', 'foo.bsp.bz2'))
        copy = File.open(Rails.root.join('spec', 'fixtures', 'foo.bsp.bz2'))

        create :map_upload, file: copy

        maps_with_path = Dir.glob(File.join(MAPS_DIR, '*.bsp*'))
        maps = maps_with_path.map { |file| File.basename(file) }
        expect(maps).to include 'foo.bsp', 'foo.bsp.bz2'
      end

      it 'sends the files to the servers' do
        source = File.open(Rails.root.join('spec', 'fixtures', 'achievement_idle.bsp.bz2'))
        FileUtils.cp(source, Rails.root.join('spec', 'fixtures', 'foo.bsp.bz2'))
        copy = File.open(Rails.root.join('spec', 'fixtures', 'foo.bsp.bz2'))

        allow(UploadFilesToServersWorker).to receive(:perform_async)

        create :map_upload, file: copy

        maps_with_paths = [Rails.root.join('tmp', 'foo.bsp').to_s]

        expect(UploadFilesToServersWorker).to have_received(:perform_async).with(files: maps_with_paths,
                                                                                 destination: 'maps',
                                                                                 overwrite: false)
      end
    end
  end

  it 'triggers the upload to the servers' do
    allow(UploadFilesToServersWorker).to receive(:perform_async)
    map_upload = create :map_upload
    maps_with_paths = [File.join(MAPS_DIR, map_upload.file.filename)]

    expect(UploadFilesToServersWorker).to have_received(:perform_async).with(files: maps_with_paths,
                                                                             destination: 'maps',
                                                                             overwrite: false)
  end
end
