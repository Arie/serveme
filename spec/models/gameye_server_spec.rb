require 'spec_helper'

describe GameyeServer do

  let(:server_config) { double(:server_config, file: "server-config-file") }
  let(:reservation) { double(:reservation, id: 12345, gameye_location: "frankfurt", first_map: "cp_badlands", rcon: "the-rcon", password: "sv-password", tv_password: "stv-password", custom_whitelist_id: "whitelist-id", server_config: server_config) }
  describe ".start_reservation" do
    it "takes reservation details and sends it to gameye" do
      GameyeServer.should_receive(:launch_gameye).with(reservation).and_return(true)
      GameyeServer.should_receive(:create_temporary_server).with(reservation)
      GameyeServer.start_reservation(reservation)
    end

    it "logs an error on failure" do
      GameyeServer.should_receive(:launch_gameye).with(reservation).and_return(500)
      reservation.should_receive(:status_update).with("Failed to launch Gameye server, got 500")
      GameyeServer.start_reservation(reservation)
    end
  end

  describe ".launch_gameye" do
    it "talks to the Gameye API", :vcr do
      expect(GameyeServer.launch_gameye(reservation)).to be_truthy
    end
  end

  describe ".location_keys" do
    it "knows the valid Gameye location keys" do
      expect(GameyeServer.location_keys).to eql ["london", "frankfurt", "moscow", "sao_paulo", "warsaw"]
    end
  end

  describe ".matches" do
    it "fetches the list of matches from Gameye API", :vcr do
      expect(GameyeServer.matches.size).to eql 2
    end
  end

  describe ".fetch_match" do
    it "finds a single running Gameye match by key", :vcr do
      expect(GameyeServer.fetch_match("serveme.tf-900490").location_key).to eql "frankfurt"
    end
  end

  describe "#end_reservation" do
    it "notifies the players and ends the match" do
      server = GameyeServer.new
      reservation.stub(:ended? => false, :reload => true)
      server.should_receive(:rcon_exec)
      GameyeServer.should_receive(:stop_reservation).with(reservation)
      server.end_reservation(reservation)
    end
  end
end
