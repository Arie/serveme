# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe ServerReservationLifecycle do
  let(:server) { build_stubbed(:server) }
  subject(:lifecycle) { described_class.new(server) }

  before { allow(server).to receive(:tf_dir).and_return("/tmp") }

  describe "#update_reservation" do
    it "rewrites the configuration" do
      reservation = instance_double(Reservation)
      expect(server).to receive(:update_configuration).with(reservation)
      lifecycle.update_reservation(reservation)
    end
  end

  describe "#enable_demos_tf" do
    it "copies the demostf plugin to the server" do
      expect(server).to receive(:copy_to_server).with(anything, "/tmp/addons/sourcemod/plugins")
      lifecycle.enable_demos_tf
    end
  end

  describe "#disable_demos_tf" do
    it "deletes the demostf plugin from the server" do
      expect(server).to receive(:delete_from_server).with([ "/tmp/addons/sourcemod/plugins/demostf.smx" ])
      lifecycle.disable_demos_tf
    end
  end

  describe "#map_present?" do
    it "checks for the map bsp on the server" do
      expect(server).to receive(:file_present?).with("/tmp/maps/cp_process_final.bsp").and_return(true)
      expect(lifecycle.map_present?("cp_process_final")).to be(true)
    end
  end

  describe "#download_stac_logs" do
    let(:reservation) { instance_double(Reservation, id: 42) }

    it "enqueues the downloader for sync-cleanup servers" do
      allow(server).to receive(:uses_async_cleanup?).and_return(false)
      expect(StacLogsDownloaderWorker).to receive(:perform_async).with(42)
      lifecycle.download_stac_logs(reservation)
    end

    it "skips it for async-cleanup servers (handled in the cleanup worker)" do
      allow(server).to receive(:uses_async_cleanup?).and_return(true)
      expect(StacLogsDownloaderWorker).not_to receive(:perform_async)
      lifecycle.download_stac_logs(reservation)
    end
  end

  describe "#start_reservation" do
    it "sends config files and stops early for cloud servers (boot handled elsewhere)" do
      reservation = instance_double(Reservation, plugins_enabled?: false, status_update: nil)
      allow(server).to receive(:supports_mitigations?).and_return(false)
      allow(server).to receive(:write_first_map)
      allow(server).to receive(:cloud?).and_return(true)

      expect(server).to receive(:update_configuration).with(reservation)
      expect(server).not_to receive(:restart)
      lifecycle.start_reservation(reservation)
    end
  end

  describe "#end_reservation" do
    let(:reservation) { instance_double(Reservation, reload: true, ended?: false, status_update: nil) }

    before do
      %i[remove_configuration disable_plugins restore_rgl_base_cfg rcon_exec rcon_disconnect
         clear_sdr_info! restart move_files_to_temp_directory delete_from_server].each do |m|
        allow(server).to receive(m)
      end
      allow(server).to receive(:uses_async_cleanup?).and_return(true)
    end

    it "cleans up, moves files for async cleanup, and restarts" do
      expect(server).to receive(:remove_configuration)
      expect(server).to receive(:move_files_to_temp_directory).with(reservation)
      expect(server).to receive(:restart)
      lifecycle.end_reservation(reservation)
    end

    it "does nothing when the reservation already ended" do
      allow(reservation).to receive(:ended?).and_return(true)
      expect(server).not_to receive(:remove_configuration)
      lifecycle.end_reservation(reservation)
    end
  end
end
