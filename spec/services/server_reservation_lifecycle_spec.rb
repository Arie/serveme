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

    context "on a non-cloud server" do
      let(:user) { build_stubbed(:user) }
      let(:reservation) do
        instance_double(Reservation, plugins_enabled?: true, demos_tf_enabled?: true, democheck_kick?: false,
                                     democheck_mode: "warn", user: user, server: server, first_map: "cp_badlands",
                                     logsecret: "1234", status_update: nil, enable_mitigations: nil)
      end

      before do
        %i[write_first_map update_configuration enable_plugins add_sourcemod_admin handle_rgl_base_cfg
           copy_to_server clear_sdr_info! restart].each { |m| allow(server).to receive(m) }
        allow(server).to receive(:supports_mitigations?).and_return(true)
        allow(server).to receive(:cloud?).and_return(false)
        allow(server).to receive(:outdated?).and_return(false)
        allow(server).to receive(:file_present?).and_return(true)
      end

      it "enables plugins, demos.tf, mitigations and RGL democheck config" do
        allow(server).to receive(:rcon_exec).and_return("ok")

        lifecycle.start_reservation(reservation)

        expect(reservation).to have_received(:enable_mitigations)
        expect(server).to have_received(:enable_plugins)
        expect(server).to have_received(:add_sourcemod_admin).with(user)
        expect(server).to have_received(:copy_to_server).with([ Rails.root.join("doc", "demostf.smx").to_s ], "/tmp/addons/sourcemod/plugins")
        expect(server).to have_received(:handle_rgl_base_cfg).with(reservation)
        expect(reservation).to have_received(:status_update).with("Setting RGL democheck mode to warn")
      end

      it "skips demos.tf and the democheck config when not wanted" do
        allow(reservation).to receive_messages(demos_tf_enabled?: false, democheck_kick?: true)
        allow(server).to receive(:rcon_exec).and_return("ok")

        lifecycle.start_reservation(reservation)

        expect(server).not_to have_received(:copy_to_server)
        expect(server).not_to have_received(:handle_rgl_base_cfg)
      end

      it "fast starts by pointing the running server at the reservation config" do
        allow(server).to receive(:rcon_exec).and_return("ok")

        lifecycle.start_reservation(reservation)

        expect(server).to have_received(:rcon_exec).with(include("sv_logsecret 1234", "servercfgfile reservation.cfg"), allow_blocked: true)
        expect(server).to have_received(:rcon_exec).with("changelevel cp_badlands; exec reservation.cfg")
        expect(server).not_to have_received(:restart)
      end

      it "fast starts on ctf_turbine when no first map was chosen" do
        allow(reservation).to receive(:first_map).and_return(nil)
        allow(server).to receive(:rcon_exec).and_return("ok")

        lifecycle.start_reservation(reservation)

        expect(server).to have_received(:rcon_exec).with("changelevel ctf_turbine; exec reservation.cfg")
      end

      it "restarts the server when the fast start rcon fails" do
        allow(server).to receive(:rcon_exec).and_return(nil)

        lifecycle.start_reservation(reservation)

        expect(server).to have_received(:clear_sdr_info!)
        expect(server).to have_received(:restart)
        expect(reservation).to have_received(:status_update).with("Fast start failed, starting server normally")
      end

      it "restarts an outdated server instead of fast starting" do
        allow(server).to receive(:outdated?).and_return(true)
        allow(server).to receive(:rcon_exec)

        lifecycle.start_reservation(reservation)

        expect(server).not_to have_received(:rcon_exec)
        expect(server).to have_received(:restart)
        expect(reservation).to have_received(:status_update).with("Server outdated, restarting server to update")
      end

      it "uploads the first map from fastdl when the server lacks it" do
        allow(server).to receive(:file_present?).with("/tmp/maps/cp_badlands.bsp").and_return(false)
        allow(server).to receive(:rcon_exec).and_return("ok")
        allow(Down).to receive(:download).with("https://fastdl.serveme.tf/maps/cp_badlands.bsp").and_return(double(path: "/tmp/down.bsp"))

        lifecycle.start_reservation(reservation)

        expect(server).to have_received(:copy_to_server).with([ "/tmp/down.bsp" ], "/tmp/maps/cp_badlands.bsp")
        expect(reservation).to have_received(:status_update).with("Uploaded map cp_badlands to server")
      end
    end
  end

  describe "#end_reservation" do
    let(:reservation) { instance_double(Reservation, id: 1, reload: true, ended?: false, status_update: nil) }

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

    it "zips and copies logs inline for sync-cleanup servers" do
      allow(server).to receive(:uses_async_cleanup?).and_return(false)
      allow(server).to receive(:logs_and_demos).and_return([ "/tmp/l.log" ])
      allow(StacLogsDownloaderWorker).to receive(:perform_async)
      expect(ZipFileCreator).to receive(:create).with(reservation, [ "/tmp/l.log" ])
      expect(LogCopier).to receive(:copy).with(reservation, server)
      expect(server).to receive(:remove_logs_and_demos)
      expect(server).not_to receive(:move_files_to_temp_directory)

      lifecycle.end_reservation(reservation)
    end

    it "does nothing when the reservation already ended" do
      allow(reservation).to receive(:ended?).and_return(true)
      expect(server).not_to receive(:remove_configuration)
      lifecycle.end_reservation(reservation)
    end
  end
end
