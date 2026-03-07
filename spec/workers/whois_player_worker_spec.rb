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
      expect_any_instance_of(Server).to receive(:rcon_say).with(/PlayerOne:/)
      expect_any_instance_of(Server).not_to receive(:rcon_say).with(/SomeGuy:/)

      subject.perform(reservation.id, "Player")
    end

    it "matches players by partial name case-insensitively" do
      expect_any_instance_of(Server).to receive(:rcon_say).with(/SomeGuy:/)

      subject.perform(reservation.id, "someguy")
    end

    it "matches players by steam ID" do
      expect_any_instance_of(Server).to receive(:rcon_say).with(/SomeGuy:/)
      expect_any_instance_of(Server).not_to receive(:rcon_say).with(/PlayerOne:/)

      subject.perform(reservation.id, "[U:1:67890]")
    end

    it "matches players by steam ID64" do
      expect_any_instance_of(Server).to receive(:rcon_say).with(/PlayerOne:/)

      subject.perform(reservation.id, "76561197960278073")
    end

    it "matches all players with *" do
      expect_any_instance_of(Server).to receive(:rcon_say).with(/PlayerOne:/).once
      expect_any_instance_of(Server).to receive(:rcon_say).with(/SomeGuy:/).once
      expect_any_instance_of(Server).to receive(:rcon_say).with(/SDRPlayer:/).once

      subject.perform(reservation.id, "*")
    end

    it "shows no match message when nobody matches" do
      expect_any_instance_of(Server).to receive(:rcon_say).with(/No players matching 'nobody'/)

      subject.perform(reservation.id, "nobody")
    end

    it "sends private messages when private_to_uid is set" do
      expect_any_instance_of(Server).to receive(:rcon_exec).with(/sm_psay #5 PlayerOne:/)
      expect_any_instance_of(Server).not_to receive(:rcon_say).with(/PlayerOne:/)

      subject.perform(reservation.id, "Player", "5")
    end

    it "does nothing if reservation does not exist" do
      expect_any_instance_of(Server).not_to receive(:rcon_say)
      subject.perform(999999, "*")
    end
  end
end
