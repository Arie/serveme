# typed: false
# frozen_string_literal: true

require 'spec_helper'
require 'sidekiq/testing'
require 'vcr'

RSpec.describe ZipUploadWorker, type: :worker do
  let(:reservation) { create(:reservation) }
  let(:zipfile_path) { Rails.root.join('spec', 'fixtures', 'files', 'test.zip') }
  let(:worker) { described_class.new }

  before(:all) do
    zip_path = Rails.root.join('spec', 'fixtures', 'files', 'test.zip')
    FileUtils.mkdir_p(File.dirname(zip_path))
    Zip::File.open(zip_path, Zip::File::CREATE) do |zipfile|
      zipfile.get_output_stream("test.txt") { |f| f.write "test content" }
    end
  end

  after(:all) do
    FileUtils.rm_f(Rails.root.join('spec', 'fixtures', 'files', 'test.zip'))
  end

  after(:each) do
    FileUtils.rm_rf(ActiveStorage::Blob.service.root) if defined?(ActiveStorage::Blob.service.root)
    Sidekiq::Worker.clear_all
  end

  describe '#perform' do
    before do
      allow(reservation).to receive(:local_zipfile_path).and_return(zipfile_path)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(zipfile_path.to_s).and_return(true)
      allow(Reservation).to receive(:find).with(reservation.id).and_return(reservation)
    end

    context 'when reservation and file exist' do
      it 'attaches the zip file to the reservation using the storage service', vcr: { cassette_name: 'minio_upload_success', match_requests_on: [ :method ] } do
        expect(reservation.zipfile).not_to be_attached

        worker.perform(reservation.id)

        reservation.reload
        expect(reservation.zipfile).to be_attached
        expect(reservation.zipfile.filename.to_s).to eq('test.zip')
        expect(reservation.zipfile.content_type).to eq('application/zip')
        expect(reservation.zipfile.blob.service_name).to eq('seaweedfs')
        expect(reservation.reservation_statuses.pluck(:status)).to include('Finished uploading zip file to storage')
      end

      it 'logs success status updates', vcr: { cassette_name: 'minio_upload_success', match_requests_on: [ :method ] } do
        worker.perform(reservation.id)
        expect(reservation.reload.reservation_statuses.pluck(:status)).to include('Finished uploading zip file to storage')
      end
    end

    context 'when blob creation fails' do
      let(:error_message) { 'Blob creation failed!' }
      let(:creation_error) { StandardError.new(error_message) }

      before do
        allow(ActiveStorage::Blob).to receive(:create_and_upload!).and_raise(creation_error)
        allow(reservation).to receive(:status_update).with(anything)
        allow(Reservation).to receive(:find_by).with(id: reservation.id).and_return(reservation)
      end

      it 'logs an error, updates status, and re-raises the error' do
        expect_any_instance_of(ActiveStorage::Attachment).not_to receive(:save)
        expect(reservation).not_to receive(:status_update).with('Finished uploading zip file to storage')

        expect(Rails.logger).to receive(:error).with(a_string_including(error_message))
        expect(reservation).to receive(:status_update).with("Failed to upload zip file (blob creation)")

        expect {
          worker.perform(reservation.id)
        }.to raise_error(creation_error)
      end
    end

    context 'when attachment save fails' do
      let(:error_message) { 'Attachment save failed!' }
      let(:save_error) { StandardError.new(error_message) }
      let(:blob) { instance_double(ActiveStorage::Blob, id: 123, key: 'fakekey') }

      before do
        allow(ActiveStorage::Blob).to receive(:create_and_upload!).and_return(blob)
        attachment_double = instance_double(ActiveStorage::Attachment)
        allow(ActiveStorage::Attachment).to receive(:new).and_return(attachment_double)
        allow(attachment_double).to receive(:save).with(validate: false).and_raise(save_error)
        allow(Reservation).to receive(:find_by).with(id: reservation.id).and_return(reservation)
        allow(reservation).to receive(:status_update).and_call_original
      end

      it 'logs an error, updates status, but does not re-raise' do
        expect(reservation).not_to receive(:status_update).with('Finished uploading zip file to storage')

        expect(Rails.logger).to receive(:error).with(a_string_including(error_message))
        expect(reservation).to receive(:status_update).with("Failed to attach zip file (attachment error)").and_call_original

        expect {
          worker.perform(reservation.id)
        }.not_to raise_error

        expect(reservation.reload.reservation_statuses.pluck(:status)).to include("Failed to attach zip file (attachment error)")
      end
    end

    context 'when zipfile already attached' do
      before do
        # Use the trait logic to attach a zipfile to the existing reservation
        blob = ActiveStorage::Blob.create!(
          key: SecureRandom.hex,
          filename: 'foo.zip',
          content_type: 'application/zip',
          byte_size: 100,
          checksum: SecureRandom.hex,
          service_name: 'seaweedfs'
        )
        ActiveStorage::Attachment.create!(
          name: 'zipfile',
          record_type: 'Reservation',
          record_id: reservation.id,
          blob_id: blob.id
        )
        allow(Reservation).to receive(:find).with(reservation.id).and_return(reservation)
      end

      it 'logs info and skips processing' do
        expect(ActiveStorage::Blob).not_to receive(:create_and_upload!)
        expect(ActiveStorage::Attachment).not_to receive(:new)
        expect(reservation).not_to receive(:status_update)

        expect(Rails.logger).to receive(:info).with(/Reservation #{reservation.id} already has zipfile attached, skipping/)

        initial_status_count = reservation.reservation_statuses.count
        expect {
          worker.perform(reservation.id)
        }.not_to raise_error

        expect(reservation.reload.reservation_statuses.count).to eq(initial_status_count)
      end
    end

    context 'when blob is nil after creation attempt' do
      before do
        allow(ActiveStorage::Blob).to receive(:create_and_upload!).and_return(nil)
        allow(Reservation).to receive(:find_by).with(id: reservation.id).and_return(reservation)
        allow(reservation).to receive(:status_update)
      end

      it 'logs error, updates status, and returns' do
        expect(Rails.logger).to receive(:error).with(/Blob object is nil/)
        expect(reservation).to receive(:status_update).with("Failed to upload zip file (blob nil)")
        expect { worker.perform(reservation.id) }.not_to raise_error
      end
    end

    context 'when attachment save returns false' do
      let(:blob) { instance_double(ActiveStorage::Blob, id: 123, key: 'fakekey') }
      let(:attachment_double) { instance_double(ActiveStorage::Attachment, errors: double(full_messages: [ 'some error' ])) }

      before do
        allow(ActiveStorage::Blob).to receive(:create_and_upload!).and_return(blob)
        allow(ActiveStorage::Attachment).to receive(:new).and_return(attachment_double)
        allow(attachment_double).to receive(:save).with(validate: false).and_return(false)
        allow(Reservation).to receive(:find_by).with(id: reservation.id).and_return(reservation)
        allow(reservation).to receive(:status_update)
      end

      it 'logs error, updates status, does not raise' do
        expect(Rails.logger).to receive(:error).with(/Failed to save Attachment record/)
        expect(reservation).to receive(:status_update).with("Failed to attach zip file (attachment save)")
        expect { worker.perform(reservation.id) }.not_to raise_error
      end
    end

    context 'when reservation does not exist' do
      it 'raises ActiveRecord::RecordNotFound' do
        allow(Reservation).to receive(:find).with(42).and_raise(ActiveRecord::RecordNotFound)
        expect { worker.perform(42) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when the zip file does not exist' do
      before do
        allow(reservation).to receive(:local_zipfile_path).and_return('/nonexistent/file.zip')
        allow(File).to receive(:open).and_call_original
        allow(File).to receive(:open).with('/nonexistent/file.zip', 'rb').and_raise(Errno::ENOENT)
        allow(Reservation).to receive(:find).with(reservation.id).and_return(reservation)
        allow(Reservation).to receive(:find_by).with(id: reservation.id).and_return(reservation)
        allow(reservation).to receive(:status_update)
      end

      it 'logs error, updates status, and raises' do
        expect(Rails.logger).to receive(:error).with(/Error during Blob creation/)
        expect(reservation).to receive(:status_update).with("Failed to upload zip file (blob creation)")
        expect { worker.perform(reservation.id) }.to raise_error(Errno::ENOENT)
      end
    end

    it 'is configured to retry 20 times' do
      expect(ZipUploadWorker.sidekiq_options['retry']).to eq(20)
    end

    it 'logs info on successful blob creation and attachment' do
      VCR.use_cassette('minio_upload_success', match_requests_on: [ :method ]) do
        allow(reservation).to receive(:zipfile).and_return(double(attached?: false))
        allow(ActiveStorage::Blob).to receive(:create_and_upload!).and_call_original
        allow(Rails.logger).to receive(:info).and_call_original
        expect(Rails.logger).to receive(:info).with(/Blob created for reservation/)
        expect(Rails.logger).to receive(:info).with(/Attachment record saved for reservation/)
        worker.perform(reservation.id)
      end
    end
  end
end
