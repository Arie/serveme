# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe DownloadZipWorker do
  let(:worker) { described_class.new }
  let(:reservation) { create(:reservation) }
  let(:tmp_dir) { Dir.mktmpdir }
  let(:local_path) { Pathname.new(File.join(tmp_dir, "nested", reservation.zipfile_name)) }
  let(:blob) { double("blob", key: "blob-key", byte_size: 10) }
  let(:zipfile) { double("zipfile", attached?: true, blob: blob) }

  before do
    allow(Reservation).to receive(:find_by).with(id: reservation.id).and_return(reservation)
    allow(reservation).to receive(:zipfile).and_return(zipfile)
    allow(reservation).to receive(:local_zipfile_path).and_return(local_path)
    allow(BetaBroadcast).to receive(:update)
    allow(BetaBroadcast).to receive(:replace)
  end

  after { FileUtils.rm_rf(tmp_dir) }

  it "does nothing when the reservation does not exist" do
    allow(Reservation).to receive(:find_by).with(id: 0).and_return(nil)

    worker.perform(0)

    expect(BetaBroadcast).not_to have_received(:update)
  end

  it "broadcasts an error when no zipfile is attached" do
    allow(zipfile).to receive(:attached?).and_return(false)

    worker.perform(reservation.id)

    expect(BetaBroadcast).to have_received(:update).with(
      reservation, target: "zip_download_progress_reservation_#{reservation.id}", content: include("No zipfile found in cloud storage.")
    )
    expect(File).not_to exist(local_path)
  end

  it "downloads the blob in chunks, reports progress and swaps in the final file" do
    allow(blob).to receive(:download).and_yield("hello").and_yield("world")

    worker.perform(reservation.id)

    expect(File.read(local_path)).to eq("helloworld")
    expect(File).not_to exist("#{local_path}.tmp")
    expect(BetaBroadcast).to have_received(:update).with(
      reservation, hash_including(partial: "reservations/zip_download_progress_bar", locals: hash_including(progress: 100, message: "Preparing... 100%"))
    )
    expect(BetaBroadcast).to have_received(:replace).with(
      reservation, hash_including(target: "zip_download_status_reservation_#{reservation.id}", partial: "reservations/direct_zip_download_link")
    )
  end

  it "throttles progress broadcasts that arrive in quick succession" do
    allow(blob).to receive(:download).and_yield("h").and_yield("e").and_yield("llo").and_yield("world")

    worker.perform(reservation.id)

    expect(BetaBroadcast).to have_received(:update).with(reservation, hash_including(partial: "reservations/zip_download_progress_bar")).once
  end

  it "reports a missing cloud file and removes the partial download" do
    allow(blob).to receive(:download).and_yield("hello").and_raise(ActiveStorage::FileNotFoundError, "gone")

    worker.perform(reservation.id)

    expect(BetaBroadcast).to have_received(:update).with(reservation, hash_including(content: include("Cloud file not found.")))
    expect(File).not_to exist("#{local_path}.tmp")
    expect(File).not_to exist(local_path)
  end

  it "reports any other download error and removes the partial download" do
    allow(blob).to receive(:download).and_raise(Errno::ECONNRESET)

    worker.perform(reservation.id)

    expect(BetaBroadcast).to have_received(:update).with(reservation, hash_including(content: include("Error during download.")))
    expect(File).not_to exist("#{local_path}.tmp")
  end
end
