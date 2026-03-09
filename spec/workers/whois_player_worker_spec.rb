# typed: false
# frozen_string_literal: true

require "spec_helper"

describe WhoisPlayerWorker do
  let(:user) { create(:user) }
  let(:server) { create(:server) }
  let(:reservation) { create(:reservation, user: user, server: server) }

  let(:status_output) do
    <<~STATUS
      hostname: serveme.tf
      # userid name uniqueid connected ping loss state adr
      #  2 "PlayerOne" [U:1:12345] 05:32 50 0 active 85.139.95.110:27005
      #  3 "SomeGuy" [U:1:67890] 02:15 30 0 active 92.60.40.231:27005
      #  4 "SDRPlayer" [U:1:11111] 01:00 20 0 active 169.254.1.1:27005
      #  5 "🍔 cant jump" [U:1:22222] 00:45 25 0 active 1.2.3.4:27005
    STATUS
  end

  before do
    allow_any_instance_of(Server).to receive(:rcon_exec).and_return("")
    allow_any_instance_of(Server).to receive(:rcon_exec).with("status").and_return(status_output)
    allow_any_instance_of(Server).to receive(:rcon_say)
    allow_any_instance_of(Server).to receive(:rcon_disconnect)
    allow(PlayerAnnouncementService).to receive(:build_info).and_return("First game")
  end

  describe "#perform" do
    it "matches players by partial name" do
      expect_any_instance_of(Server).to receive(:rcon_exec).with(/sm_psay #7 PlayerOne:/)
      expect_any_instance_of(Server).not_to receive(:rcon_exec).with(/sm_psay #7 SomeGuy:/)

      subject.perform(reservation.id, "Player", "7", true)
    end

    it "matches players by partial name case-insensitively" do
      expect_any_instance_of(Server).to receive(:rcon_exec).with(/sm_psay #7 SomeGuy:/)

      subject.perform(reservation.id, "someguy", "7", true)
    end

    it "matches players by steam ID" do
      expect_any_instance_of(Server).to receive(:rcon_exec).with(/sm_psay #7 SomeGuy:/)
      expect_any_instance_of(Server).not_to receive(:rcon_exec).with(/sm_psay #7 PlayerOne:/)

      subject.perform(reservation.id, "[U:1:67890]", "7", true)
    end

    it "matches players by steam ID64" do
      expect_any_instance_of(Server).to receive(:rcon_exec).with(/sm_psay #7 PlayerOne:/)

      subject.perform(reservation.id, "76561197960278073", "7", true)
    end

    it "matches all players with *" do
      expect_any_instance_of(Server).to receive(:rcon_exec).with(/sm_psay #7 PlayerOne:/).once
      expect_any_instance_of(Server).to receive(:rcon_exec).with(/sm_psay #7 SomeGuy:/).once
      expect_any_instance_of(Server).to receive(:rcon_exec).with(/sm_psay #7 SDRPlayer:/).once

      subject.perform(reservation.id, "*", "7", true)
    end

    it "shows no match message when nobody matches" do
      expect_any_instance_of(Server).to receive(:rcon_exec).with(/sm_psay #7 No players matching 'nobody'/)

      subject.perform(reservation.id, "nobody", "7", true)
    end

    it "always sends private messages" do
      expect_any_instance_of(Server).to receive(:rcon_exec).with(/sm_psay #5 PlayerOne:/)
      expect_any_instance_of(Server).not_to receive(:rcon_say).with(/PlayerOne:/)

      subject.perform(reservation.id, "Player", "5", false)
    end

    it "includes ISP info for reserver" do
      expect(PlayerAnnouncementService).to receive(:build_info).with(anything, anything, reserver: true).and_return("info")

      subject.perform(reservation.id, "Player", "7", true)
    end

    it "excludes ISP info for non-reserver" do
      expect(PlayerAnnouncementService).to receive(:build_info).with(anything, anything, reserver: false).and_return("info")

      subject.perform(reservation.id, "Player", "5", false)
    end

    it "matches emoji players by emoji name" do
      expect_any_instance_of(Server).to receive(:rcon_exec).with(/sm_psay #7 .*cant jump:/)

      subject.perform(reservation.id, "burger", "7", true)
    end

    it "does nothing if reservation does not exist" do
      expect_any_instance_of(Server).not_to receive(:rcon_say)
      subject.perform(999999, "*", "7", true)
    end
  end
end
