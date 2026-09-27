# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe MapUpload do
  include ActionDispatch::TestProcess::FixtureFile

  subject do
    file = file_fixture_upload('achievement_idle.bsp', 'application/octet-stream')
    map_upload = described_class.new
    map_upload.file = file
    map_upload
  end
  it 'requires a user' do
    subject.valid?
    subject.should have(1).error_on(:user_id)
  end

  it 'fails on a bad map file' do
    bad_map = file_fixture_upload('cfg.zip', 'application/octet-stream')
    subject.file = bad_map
    subject.valid?
    expect(subject.errors.full_messages).to include('File not a map (bsp) file')
  end

  describe '.fetch_bucket_objects' do
    before do
      allow(ActiveStorage::Blob.service).to receive(:respond_to?).and_call_original
      allow(ActiveStorage::Blob.service).to receive(:respond_to?).with(:bucket).and_return(true)

      allow(MapUpload).to receive(:new).and_wrap_original do |method, *args, **kwargs|
        instance = method.call(*args, **kwargs)
        allow(instance).to receive(:refresh_available_maps)
        instance
      end
    end

    context 'with real map upload records' do
      let!(:user1) { create :user, nickname: 'MapMaker1' }
      let!(:legacy_user) { create :user, nickname: 'LegacyMapper' }

      let!(:blob) do
        ActiveStorage::Blob.create!(
          key: 'maps/cp_badlands.bsp',
          filename: 'cp_badlands.bsp',
          byte_size: 1024,
          checksum: 'abc123',
          content_type: 'application/octet-stream'
        )
      end

      let!(:new_upload) do
        upload = MapUpload.create!(user: user1)
        ActiveStorage::Attachment.create!(
          name: 'file',
          record: upload,
          blob: blob
        )
        upload
      end

      let!(:legacy_upload) do
        upload = MapUpload.create!(user: legacy_user)
        upload.update_column(:file, 'cp_dustbowl.bsp')
        upload
      end

      before do
        mock_badlands = double('BucketObject', key: 'maps/cp_badlands.bsp', size: 1024000)
        mock_dustbowl = double('BucketObject', key: 'maps/cp_dustbowl.bsp', size: 750000)
        mock_unknown = double('BucketObject', key: 'maps/cp_unknown.bsp', size: 512000)

        mock_bucket = double('Bucket')
        allow(mock_bucket).to receive(:objects).with(prefix: 'maps/').and_return([
          mock_badlands, mock_dustbowl, mock_unknown
        ])
        allow(ActiveStorage::Blob.service).to receive(:bucket).and_return(mock_bucket)
      end

      it 'includes uploader information for both new and legacy maps' do
        result = MapUpload.fetch_bucket_objects

        badlands_entry = result.find { |obj| obj[:map_name] == 'cp_badlands' }
        dustbowl_entry = result.find { |obj| obj[:map_name] == 'cp_dustbowl' }
        unknown_entry = result.find { |obj| obj[:map_name] == 'cp_unknown' }

        expect(badlands_entry[:uploader]).to eq(user1)
        expect(badlands_entry[:upload_date]).to be_within(1.second).of(new_upload.created_at)

        expect(dustbowl_entry[:uploader]).to eq(legacy_user)
        expect(dustbowl_entry[:upload_date]).to be_within(1.second).of(legacy_upload.created_at)

        expect(unknown_entry[:uploader]).to be_nil
        expect(unknown_entry[:upload_date]).to be_nil
      end
    end
  end

  describe '.sanitize_map_name' do
    it 'rejects names containing path traversal' do
      expect { MapUpload.sanitize_map_name('../etc/passwd') }.to raise_error(ArgumentError)
    end
  end

  describe '.validate_s3_key' do
    it 'accepts a valid key matching maps/filename' do
      expect { MapUpload.validate_s3_key('maps/cp_badlands.bsp', 'cp_badlands.bsp') }.not_to raise_error
    end

    it 'rejects a key that does not start with maps/' do
      expect { MapUpload.validate_s3_key('other/cp_badlands.bsp', 'cp_badlands.bsp') }.to raise_error(ArgumentError)
    end

    it 'rejects a key that does not match the filename' do
      expect { MapUpload.validate_s3_key('maps/cp_other.bsp', 'cp_badlands.bsp') }.to raise_error(ArgumentError)
    end
  end

  describe '.delete_bucket_object' do
    it 'deletes a valid map name' do
      allow(ActiveStorage::Blob.service).to receive(:delete)
      allow(Rails.cache).to receive(:delete)
      allow(Rails.cache).to receive(:write)
      allow(MapUpload).to receive(:bucket_objects).and_return([])
      allow(MapUpload).to receive(:map_statistics).and_return({})
      allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)

      expect { MapUpload.delete_bucket_object('cp_badlands') }.not_to raise_error
      expect(ActiveStorage::Blob.service).to have_received(:delete).with('maps/cp_badlands.bsp')
      expect(ActiveStorage::Blob.service).to have_received(:delete).with('maps/cp_badlands.bsp.bz2')
    end
  end
  describe '#refresh_available_maps' do
    it 'enqueues the available maps worker after save' do
      expect(AvailableMapsWorker).to receive(:perform_async)
      described_class.create!(user: create(:user))
    end
  end

  describe '.available_maps' do
    it 'returns the map names of the bucket objects' do
      allow(described_class).to receive(:bucket_objects).and_return([
        { key: 'maps/cp_badlands.bsp', map_name: 'cp_badlands' },
        { key: 'maps/koth_product.bsp', map_name: 'koth_product' }
      ])
      expect(described_class.available_maps).to eq(%w[cp_badlands koth_product])
    end
  end

  describe '.bucket_objects' do
    it 'caches the fetched bucket objects' do
      objects = [ { key: 'maps/cp_badlands.bsp', map_name: 'cp_badlands' } ]
      expect(described_class).to receive(:fetch_bucket_objects).once.and_return(objects)

      expect(described_class.bucket_objects).to eq(objects)
      expect(described_class.bucket_objects).to eq(objects)
    end
  end

  describe '.refresh_bucket_objects' do
    it 'clears map list caches and stores freshly fetched objects' do
      Rails.cache.write('map-list-view-for-admin-false', 'stale')
      Rails.cache.write('map-list-view-for-admin-true', 'stale')
      Rails.cache.write('api_maps_text', 'stale')
      Rails.cache.write('map_bucket_objects', [ { map_name: 'old' } ])
      fresh = [ { key: 'maps/cp_new.bsp', map_name: 'cp_new' } ]
      allow(described_class).to receive(:fetch_bucket_objects).and_return(fresh)

      allow(Rails.cache).to receive(:write).and_call_original

      described_class.refresh_bucket_objects

      expect(Rails.cache).to have_received(:write).with('map_bucket_objects', fresh, expires_in: 11.minutes)
      expect(Rails.cache.read('map-list-view-for-admin-false')).to be_nil
      expect(Rails.cache.read('map-list-view-for-admin-true')).to be_nil
      expect(Rails.cache.read('api_maps_text')).to be_nil
      expect(Rails.cache.read('map_bucket_objects')).to eq(fresh)
    end
  end

  describe '.fake_bucket_objects' do
    it 'returns bsp entries without uploaders' do
      objects = described_class.fake_bucket_objects
      expect(objects).not_to be_empty
      expect(objects.first).to eq(key: 'maps/cp_process_f12.bsp', map_name: 'cp_process_f12', size: 0, uploader: nil, upload_date: nil)
      expect(objects).to all(satisfy { |o| o[:key] == "maps/#{o[:map_name]}.bsp" })
    end

    it 'is used by fetch_bucket_objects in development' do
      allow(Rails.env).to receive(:development?).and_return(true)
      expect(described_class.fetch_bucket_objects).to eq(described_class.fake_bucket_objects)
    end
  end

  describe '.fetch_bucket_objects without a bucket-capable service' do
    it 'returns an empty list' do
      allow(ActiveStorage::Blob.service).to receive(:respond_to?).and_call_original
      allow(ActiveStorage::Blob.service).to receive(:respond_to?).with(:bucket).and_return(false)
      expect(described_class.fetch_bucket_objects).to eq([])
    end
  end

  describe 'map statistics' do
    let!(:reservation1) { create :reservation }
    let!(:reservation2) { create :reservation, starts_at: reservation1.ends_at + 1.hour, ends_at: reservation1.ends_at + 2.hours }

    before do
      reservation1.update_columns(first_map: 'cp_badlands', starts_at: 3.days.ago)
      reservation2.update_columns(first_map: 'cp_badlands', starts_at: 1.day.ago)
      create(:reservation).update_columns(first_map: '', starts_at: 2.days.ago)
    end

    it 'aggregates play counts and dates per first map' do
      stats = described_class.fetch_map_statistics

      expect(stats.keys).to eq([ 'cp_badlands' ])
      expect(stats['cp_badlands'][:times_played]).to eq(2)
      expect(stats['cp_badlands'][:first_played]).to be_within(1.second).of(reservation1.starts_at)
      expect(stats['cp_badlands'][:last_played]).to be_within(1.second).of(reservation2.starts_at)
    end

    it 'caches statistics and refreshes them on demand' do
      expect(described_class.map_statistics['cp_badlands'][:times_played]).to eq(2)

      reservation1.update_column(:first_map, 'koth_product')
      expect(described_class.map_statistics.keys).to eq([ 'cp_badlands' ])

      allow(Rails.cache).to receive(:write).and_call_original
      described_class.refresh_map_statistics
      expect(Rails.cache).to have_received(:write).with('map_statistics', anything, expires_in: 11.minutes)
      expect(described_class.map_statistics.keys).to contain_exactly('cp_badlands', 'koth_product')
    end
  end

  describe '.blacklisted_type?' do
    it 'flags blacklisted game types' do
      expect(described_class.blacklisted_type?('mvm_decoy.bsp')).to be true
      expect(described_class.blacklisted_type?('VSH_something.bsp')).to be true
    end

    it 'allows regular maps' do
      expect(described_class.blacklisted_type?('cp_badlands.bsp')).to be false
    end

    it 'returns nil for non-bsp filenames' do
      expect(described_class.blacklisted_type?('mvm_decoy.zip')).to be_nil
    end
  end

  describe 'blacklisted type validation' do
    it 'rejects blacklisted map types' do
      subject.valid?
      expect(subject.errors.full_messages).to include('File game type not allowed')
    end
  end

  describe '.create_from_direct_upload' do
    let(:user) { create :user }
    let(:key) { 'maps/cp_granlands123.bsp' }
    let(:filename) { 'cp_granlands123.bsp' }

    it 'rejects invalid keys without touching storage' do
      expect(described_class).not_to receive(:validate_direct_upload_file)
      result = described_class.create_from_direct_upload(user: user, key: 'maps/../evil.bsp', filename: '../evil.bsp')
      expect(result[:success]).to be false
      expect(result[:error]).to match(/Invalid map name/)
    end

    it 'rejects keys that already have a blob' do
      ActiveStorage::Blob.create!(key: key, filename: filename, byte_size: 1, checksum: 'abc', content_type: 'application/octet-stream')
      expect(described_class).not_to receive(:validate_direct_upload_file)
      result = described_class.create_from_direct_upload(user: user, key: key, filename: filename)
      expect(result).to eq(success: false, error: 'File already exists in database')
    end

    it 'deletes the uploaded object when validation fails' do
      allow(described_class).to receive(:validate_direct_upload_file).with(key).and_return(valid: false, error: 'Not a valid BSP file')
      expect(ActiveStorage::Blob.service).to receive(:delete).with(key)
      result = described_class.create_from_direct_upload(user: user, key: key, filename: filename)
      expect(result).to eq(success: false, error: 'Not a valid BSP file')
    end

    it 'still returns the validation error when deleting the invalid object fails' do
      allow(described_class).to receive(:validate_direct_upload_file).with(key).and_return(valid: false, error: 'File not found')
      allow(ActiveStorage::Blob.service).to receive(:delete).with(key).and_raise(StandardError, 'boom')
      expect(Rails.logger).to receive(:error).with("Failed to delete invalid file #{key}: boom")
      result = described_class.create_from_direct_upload(user: user, key: key, filename: filename)
      expect(result).to eq(success: false, error: 'File not found')
    end

    context 'when the file is valid' do
      before do
        allow(described_class).to receive(:validate_direct_upload_file).with(key).and_return(valid: true, size: 1234, checksum: 'Q2hlY2tzdW0=')
        # The cloudflare (S3) service would reach for AWS credentials; use the local disk service instead
        allow(ActiveStorage::Blob.services).to receive(:fetch).and_call_original
        allow(ActiveStorage::Blob.services).to receive(:fetch).with('cloudflare').and_return(ActiveStorage::Blob.service)
        # Simulate the browser's direct upload having put the file in the bucket
        ActiveStorage::Blob.service.upload(key, file_fixture('cp_granlands123.bsp').open)
      end

      after { ActiveStorage::Blob.service.delete(key) }

      it 'creates a blob with the uploaded key and attaches it to a new map upload' do
        result = nil
        expect { result = described_class.create_from_direct_upload(user: user, key: key, filename: filename) }.to change(described_class, :count).by(1)

        expect(result[:success]).to be true
        map_upload = result[:map_upload]
        expect(map_upload).to be_persisted
        expect(map_upload.user).to eq(user)
        blob = map_upload.file.blob
        expect(blob.key).to eq(key)
        expect(blob.filename.to_s).to eq(filename)
        expect(blob.byte_size).to eq(1234)
        expect(blob.service_name).to eq('cloudflare')
      end

      it 'returns validation errors when the map upload cannot be saved' do
        blacklisted_key = 'maps/mvm_decoy.bsp'
        allow(described_class).to receive(:validate_direct_upload_file).with(blacklisted_key).and_return(valid: true, size: 1, checksum: 'Q2hlY2tzdW0=')
        ActiveStorage::Blob.service.upload(blacklisted_key, file_fixture('cp_granlands123.bsp').open)

        expect do
          result = described_class.create_from_direct_upload(user: user, key: blacklisted_key, filename: 'mvm_decoy.bsp')
          expect(result).to eq(success: false, error: 'File game type not allowed')
        end.not_to change(described_class, :count)

        expect(ActiveStorage::Blob.find_by(key: blacklisted_key)).to be_nil
        expect(ActiveStorage::Blob.service.exist?(blacklisted_key)).to be false
      ensure
        ActiveStorage::Blob.service.delete(blacklisted_key)
      end

      it 'removes the blob when attaching raises, so the upload can be retried' do
        allow_any_instance_of(ActiveStorage::Attached::One).to receive(:attach).and_raise(ActiveRecord::RecordInvalid)

        result = described_class.create_from_direct_upload(user: user, key: key, filename: filename)

        expect(result).to eq(success: false, error: 'Failed to complete upload')
        expect(ActiveStorage::Blob.find_by(key: key)).to be_nil
      end

      it 'returns a generic error when blob creation raises' do
        allow(ActiveStorage::Blob).to receive(:create_before_direct_upload!).and_raise(ActiveRecord::RecordInvalid)
        expect(Rails.logger).to receive(:error).with(/Error completing upload/)
        result = described_class.create_from_direct_upload(user: user, key: key, filename: filename)
        expect(result).to eq(success: false, error: 'Failed to complete upload')
      end
    end
  end

  describe '.validate_direct_upload_file' do
    let(:key) { 'maps/cp_badlands.bsp' }
    let(:s3_client) { double('S3Client') }

    before do
      s3_resource = double('S3Resource', client: s3_client)
      allow(ActiveStorage::Blob.service).to receive(:client).and_return(s3_resource)
      allow(Rails.application.credentials).to receive(:dig).and_call_original
      allow(Rails.application.credentials).to receive(:dig).with(:cloudflare, :bucket).and_return('maps-bucket')
      allow(s3_client).to receive(:head_object).with(bucket: 'maps-bucket', key: key).and_return(double(content_length: 8))
    end

    it 'returns size and MD5 checksum for a valid BSP' do
      content = 'VBSPdata'
      allow(s3_client).to receive(:get_object).with(bucket: 'maps-bucket', key: key, range: 'bytes=0-3').and_return(double(body: StringIO.new('VBSP')))
      allow(s3_client).to receive(:get_object).with(bucket: 'maps-bucket', key: key).and_return(double(body: StringIO.new(content)))

      expect(described_class.validate_direct_upload_file(key)).to eq(valid: true, size: 8, checksum: Digest::MD5.base64digest(content))
    end

    it 'rejects files without a VBSP header' do
      allow(s3_client).to receive(:get_object).with(bucket: 'maps-bucket', key: key, range: 'bytes=0-3').and_return(double(body: StringIO.new('PK\x03\x04')))
      expect(s3_client).not_to receive(:get_object).with(bucket: 'maps-bucket', key: key)

      expect(described_class.validate_direct_upload_file(key)).to eq(valid: false, error: 'Not a valid BSP file')
    end

    it 'reports missing files' do
      allow(s3_client).to receive(:head_object).and_raise(Aws::S3::Errors::NoSuchKey.new(nil, 'missing'))
      expect(described_class.validate_direct_upload_file(key)).to eq(valid: false, error: 'File not found')
    end

    it 'reports other errors generically' do
      allow(s3_client).to receive(:head_object).and_raise(StandardError, 'timeout')
      expect(Rails.logger).to receive(:error).with("Error validating file #{key}: timeout")
      expect(described_class.validate_direct_upload_file(key)).to eq(valid: false, error: 'Failed to validate file')
    end
  end

  describe 'file helpers' do
    let(:user) { create :user }

    context 'with an ActiveStorage upload' do
      let(:map_upload) do
        blob = ActiveStorage::Blob.create!(key: 'maps/cp_badlands.bsp', filename: 'cp_badlands.bsp', byte_size: 3 * 1024 * 1024, checksum: 'abc', content_type: 'application/octet-stream')
        upload = described_class.create!(user: user)
        ActiveStorage::Attachment.create!(name: 'file', record: upload, blob: blob)
        upload.reload
      end

      it 'uses the blob for filename, map name, size and existence' do
        expect(map_upload.filename).to eq('cp_badlands.bsp')
        expect(map_upload.map_name).to eq('cp_badlands')
        expect(map_upload.file_size).to eq(3 * 1024 * 1024)
        expect(map_upload.formatted_file_size).to eq('3.0 MB')
        expect(map_upload.file_exists?).to be true
      end
    end

    context 'with a legacy CarrierWave upload' do
      let(:map_upload) do
        upload = described_class.create!(user: user)
        upload.update_column(:file, 'cp_dustbowl.bsp')
        upload
      end

      before do
        allow(described_class).to receive(:bucket_objects).and_return([
          { key: 'maps/cp_dustbowl.bsp', map_name: 'cp_dustbowl', size: 1_572_864 }
        ])
      end

      it 'uses the file column for filename and map name' do
        expect(map_upload.filename).to eq('cp_dustbowl.bsp')
        expect(map_upload.map_name).to eq('cp_dustbowl')
      end

      it 'prefers preloaded lookups over the bucket listing' do
        expect(map_upload.file_size(map_upload.id => 42)).to eq(42)
        expect(map_upload.file_exists?(map_upload.id => false)).to be false
        expect(described_class).not_to have_received(:bucket_objects)
      end

      it 'falls back to the bucket listing' do
        expect(map_upload.file_size).to eq(1_572_864)
        expect(map_upload.formatted_file_size).to eq('1.5 MB')
        expect(map_upload.file_exists?).to be true
        expect(map_upload.file_size(map_upload.id + 1 => 42)).to eq(1_572_864)
      end

      it 'reports missing files when not in the bucket' do
        allow(described_class).to receive(:bucket_objects).and_return([])
        expect(map_upload.file_size).to be_nil
        expect(map_upload.formatted_file_size).to eq('Unknown')
        expect(map_upload.file_exists?).to be false
      end
    end

    context 'with only a name' do
      let(:map_upload) { described_class.new(user: user, name: 'koth_product.bsp') }

      it 'falls back to the name for filename and map name' do
        expect(map_upload.filename).to eq('koth_product.bsp')
        expect(map_upload.map_name).to eq('koth_product')
        expect(map_upload.file_size).to be_nil
        expect(map_upload.formatted_file_size).to eq('Unknown')
        expect(map_upload.file_exists?).to be false
      end
    end

    context 'without any file information' do
      let(:map_upload) { described_class.new(user: user) }

      it 'returns nil for filename and map name' do
        expect(map_upload.filename).to be_nil
        expect(map_upload.map_name).to be_nil
      end
    end
  end
end
