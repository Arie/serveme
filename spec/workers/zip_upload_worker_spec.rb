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
  end

  describe '#perform' do
    context 'when reservation and file exist' do
      it 'attaches the zip file to the reservation using the minio service', vcr: { cassette_name: 'minio_upload_success', match_requests_on: [ :method ] } do
        expect(reservation.zipfile).not_to be_attached

        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(zipfile_path.to_s).and_return(true)

        expect_any_instance_of(Reservation).to receive(:status_update).with('Uploading zip file to storage')
        expect_any_instance_of(Reservation).to receive(:status_update).with('Finished uploading zip file to storage')

        worker.perform(reservation.id, zipfile_path.to_s)

        reservation.reload
        expect(reservation.zipfile).to be_attached
        expect(reservation.zipfile.filename.to_s).to eq('test.zip')
        expect(reservation.zipfile.content_type).to eq('application/zip')
        expect(reservation.zipfile.blob.service_name).to eq('minio')
      end

      it 'logs success status updates', vcr: { cassette_name: 'minio_upload_success', match_requests_on: [ :method ] } do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(zipfile_path.to_s).and_return(true)
        worker.perform(reservation.id, zipfile_path.to_s)
        expect(reservation.reservation_statuses.pluck(:status)).to include('Uploading zip file to storage')
        expect(reservation.reservation_statuses.pluck(:status)).to include('Finished uploading zip file to storage')
      end
    end

    context 'when reservation does not exist' do
      it 'logs an error and returns' do
        expect(Rails.logger).to receive(:error).with(/Reservation not found with ID 999/)
        expect_any_instance_of(Reservation).not_to receive(:status_update)
        worker.perform(999, zipfile_path.to_s)
      end
    end

    context 'when zip file does not exist' do
      let(:non_existent_path) { '/tmp/non_existent_file.zip' }

      it 'logs an error, updates status, and returns' do
        allow(File).to receive(:exist?).with(non_existent_path).and_return(false)
        expect(Rails.logger).to receive(:error).with(/Zip file not found at path #{non_existent_path}/)
        expect_any_instance_of(Reservation).to receive(:status_update).with("Failed to upload zip file: File not found at #{non_existent_path}")

        worker.perform(reservation.id, non_existent_path)

        expect(reservation.zipfile).not_to be_attached
      end
    end

    context 'when attaching the file fails' do
      let(:error_message) { 'Upload failed!' }
      let(:upload_error) { StandardError.new(error_message) }

      before do
        allow(File).to receive(:exist?).with(zipfile_path.to_s).and_return(true)
        allow(upload_error).to receive(:message).and_return(error_message)
      end

      it 'logs an error, updates status, and re-raises the error' do
        expect_any_instance_of(Reservation).to receive(:status_update).with('Uploading zip file to storage')
        expect(Rails.logger).to receive(:error).with(/Failed to upload zip for reservation #{reservation.id}: #{error_message}/)
        expect_any_instance_of(Reservation).to receive(:status_update).with("Failed to upload zip file")

        allow_any_instance_of(ActiveStorage::Attached::One).to receive(:attach).and_raise(upload_error)

        expect {
          worker.perform(reservation.id, zipfile_path.to_s)
        }.to raise_error(upload_error)

        expect(reservation.reservation_statuses.pluck(:status)).not_to include("Finished uploading zip file to storage")
      end
    end
  end
end
