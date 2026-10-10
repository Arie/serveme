# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe BackfillZipfileWorker do
  let(:worker) { described_class.new }
  let(:reservation) { create(:reservation) }
  let(:tmp_dir) { Dir.mktmpdir }
  let(:local_path) { Pathname.new(File.join(tmp_dir, reservation.zipfile_name)) }
  let(:blob) do
    ActiveStorage::Blob.create!(
      key: SecureRandom.hex, filename: reservation.zipfile_name, content_type: "application/zip",
      byte_size: 3, checksum: SecureRandom.hex, service_name: "seaweedfs"
    )
  end

  before do
    File.write(local_path, "zip")
    allow(Reservation).to receive(:find_by).with(id: reservation.id).and_return(reservation)
    allow(reservation).to receive(:local_zipfile_path).and_return(local_path)
  end

  after { FileUtils.rm_rf(tmp_dir) }

  it "uploads the local zip and attaches it to the reservation" do
    expect(ActiveStorage::Blob).to receive(:create_and_upload!).with(
      io: kind_of(File), filename: reservation.zipfile_name, content_type: "application/zip", service_name: :seaweedfs
    ).and_return(blob)

    worker.perform(reservation.id)

    expect(Reservation.find(reservation.id).zipfile.blob).to eq(blob)
  end

  it "skips missing reservations" do
    allow(Reservation).to receive(:find_by).with(id: 0).and_return(nil)
    expect(ActiveStorage::Blob).not_to receive(:create_and_upload!)

    worker.perform(0)
  end

  it "skips reservations that already have a zipfile attached" do
    allow(reservation).to receive(:zipfile).and_return(double(attached?: true))
    expect(ActiveStorage::Blob).not_to receive(:create_and_upload!)

    worker.perform(reservation.id)
  end

  it "skips reservations without a local zip" do
    FileUtils.rm_f(local_path)
    expect(ActiveStorage::Blob).not_to receive(:create_and_upload!)

    worker.perform(reservation.id)
  end

  it "does not attach anything when the upload returns no blob" do
    allow(ActiveStorage::Blob).to receive(:create_and_upload!).and_return(nil)

    expect { worker.perform(reservation.id) }.not_to change(ActiveStorage::Attachment, :count)
  end

  it "does not attach anything when the upload fails" do
    allow(ActiveStorage::Blob).to receive(:create_and_upload!).and_raise(Aws::S3::Errors::ServiceError.new(nil, "boom"))
    expect(Rails.logger).to receive(:error).with(/Failed to create blob.*boom/m)

    expect { worker.perform(reservation.id) }.not_to change(ActiveStorage::Attachment, :count)
  end

  it "logs when the attachment cannot be saved" do
    allow(ActiveStorage::Blob).to receive(:create_and_upload!).and_return(blob)
    attachment = instance_double(ActiveStorage::Attachment, save: false, errors: double(full_messages: [ "Record must exist" ]))
    allow(ActiveStorage::Attachment).to receive(:new).and_return(attachment)
    expect(Rails.logger).to receive(:error).with(/Failed to save Attachment.*Record must exist/)

    worker.perform(reservation.id)
  end

  it "logs when saving the attachment raises" do
    allow(ActiveStorage::Blob).to receive(:create_and_upload!).and_return(blob)
    allow(ActiveStorage::Attachment).to receive(:new).and_raise(ActiveRecord::StatementInvalid, "db down")
    expect(Rails.logger).to receive(:error).with(/Error during Attachment save.*db down/m)

    worker.perform(reservation.id)
  end
end
