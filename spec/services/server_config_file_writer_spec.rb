# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe ServerConfigFileWriter do
  let(:server) { build_stubbed(:server) }
  subject(:writer) { described_class.new(server) }

  before { allow(server).to receive(:tf_dir).and_return("/tmp") }

  describe "#enable_plugins" do
    it "writes the sourcemod metamod vdf" do
      expect(server).to receive(:write_configuration).with("/tmp/addons/metamod/sourcemod.vdf", a_string_including("sourcemod"))
      writer.enable_plugins
    end
  end

  describe "#disable_plugins" do
    it "deletes the sourcemod plugin and admin files" do
      expect(server).to receive(:delete_from_server).with([
        "/tmp/addons/metamod/sourcemod.vdf",
        "/tmp/addons/sourcemod/configs/admins_simple.ini"
      ])
      writer.disable_plugins
    end
  end

  describe "#add_sourcemod_admin" do
    let(:user) { build_stubbed(:user, uid: "76561197960497430") }

    it "grants full flags on an SDR server" do
      allow(server).to receive(:sdr?).and_return(true)
      expect(server).to receive(:write_configuration).with(
        "/tmp/addons/sourcemod/configs/admins_simple.ini", a_string_including("99:abcdefghijkln")
      ).and_return(true)
      writer.add_sourcemod_admin(user)
    end

    it "grants reservation-only flags on a non-SDR server" do
      allow(server).to receive(:sdr?).and_return(false)
      expect(server).to receive(:write_configuration).with(anything, a_string_including("99:z")).and_return(true)
      writer.add_sourcemod_admin(user)
    end
  end

  describe "#add_motd" do
    it "writes a motd url pointing at the reservation" do
      reservation = instance_double(Reservation, id: 1337, password: "secret")
      expect(server).to receive(:write_configuration).with("/tmp/motd.txt", a_string_including("/reservations/1337/motd?password=secret")).and_return(true)
      writer.add_motd(reservation)
    end
  end

  describe "#handle_rgl_base_cfg" do
    let(:rgl_base) { File.read(Rails.root.join("doc", "rgl_base.cfg")) }

    it "writes the unmodified cfg in kick mode" do
      expect(server).to receive(:write_configuration).with("/tmp/cfg/rgl_base.cfg", rgl_base)
      writer.handle_rgl_base_cfg(instance_double(Reservation, democheck_mode: "kick"))
    end

    it "enables warn mode" do
      expected = rgl_base.gsub("sm_democheck_warn 0", "sm_democheck_warn 1")
      expect(server).to receive(:write_configuration).with("/tmp/cfg/rgl_base.cfg", expected)
      writer.handle_rgl_base_cfg(instance_double(Reservation, democheck_mode: "warn"))
    end

    it "disables democheck" do
      expected = rgl_base
        .gsub("sm_democheck_enabled 1", "sm_democheck_enabled 0")
        .gsub("sm_democheck_announce 1", "sm_democheck_announce 0")
      expect(server).to receive(:write_configuration).with("/tmp/cfg/rgl_base.cfg", expected)
      writer.handle_rgl_base_cfg(instance_double(Reservation, democheck_mode: "disable"))
    end
  end

  describe "#restore_rgl_base_cfg" do
    it "writes the pristine rgl_base cfg" do
      pristine = File.read(Rails.root.join("doc", "rgl_base.cfg"))
      expect(server).to receive(:write_configuration).with("/tmp/cfg/rgl_base.cfg", pristine)
      writer.restore_rgl_base_cfg
    end
  end

  describe "#write_custom_whitelist" do
    it "writes the whitelist content" do
      reservation = instance_double(Reservation, custom_whitelist_id: 1337, custom_whitelist_content: "foobar")
      expect(server).to receive(:write_configuration).with("/tmp/cfg/custom_whitelist_1337.txt", "foobar")
      writer.write_custom_whitelist(reservation)
    end

    it "does nothing when there is no content" do
      reservation = instance_double(Reservation, custom_whitelist_id: 1337, custom_whitelist_content: nil)
      expect(server).not_to receive(:write_configuration)
      writer.write_custom_whitelist(reservation)
    end
  end

  describe "#write_maplist" do
    it "writes the sorted available maps" do
      allow(MapUpload).to receive(:available_maps).and_return(%w[koth_product cp_process])
      expect(server).to receive(:write_configuration).with("/tmp/cfg/maplist_full.txt", "cp_process\nkoth_product")
      writer.write_maplist
    end
  end

  describe "#update_configuration" do
    it "generates and writes every reservation config file" do
      reservation = instance_double(
        Reservation,
        status_update: instance_double(ReservationStatus),
        custom_whitelist_id: nil,
        democheck_mode: "kick",
        id: 1337,
        password: "secret"
      )
      allow(writer).to receive(:generate_config_file).and_return("cfg contents")
      writes = []
      allow(server).to receive(:write_configuration) { |path, _content| writes << path }

      writer.update_configuration(reservation)

      expect(writes).to include(
        "/tmp/cfg/reservation.cfg",
        "/tmp/cfg/ctf_turbine.cfg",
        "/tmp/cfg/rgl_base.cfg",
        "/tmp/motd.txt",
        "/tmp/cfg/maplist_full.txt"
      )
    end
  end

  describe "#generate_config_file" do
    it "renders the erb template in the reservation's binding" do
      reservation = create(:reservation)
      expect(writer.generate_config_file(reservation, "reservation.cfg")).to be_a(String)
    end
  end
end
