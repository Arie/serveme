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
end
