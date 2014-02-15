require 'spec_helper'

describe ServerNumberOfPlayersWorker do

  let(:reservation) { create :reservation }
  before do
    Reservation.should_receive(:find).with(reservation.id).and_return { reservation }
  end


  it "finds the server to check" do
    server = double(:server, :occupied? => true, :number_of_players => 1)
    reservation.should_receive(:server).at_least(:once).and_return { server }
    ServerNumberOfPlayersWorker.perform_async(reservation.id)
  end

  context "occupied server" do

    let(:server) { double(:server, :occupied? => true, :number_of_players => 1) }

    it "saves the number of players and resets the inactive minutes" do
      reservation.stub(:server => server)

      reservation.should_receive(:update_column).with(:last_number_of_players,  1)
      reservation.should_receive(:update_column).with(:inactive_minute_counter, 0)
      ServerNumberOfPlayersWorker.perform_async(reservation.id)
    end

  end

  context "unoccupied server" do

    let(:server) { double(:server, :occupied? => false, :number_of_players => 0) }

    it "saves the number of players and resets the inactive minutes" do
      reservation.stub(:server => server)

      reservation.should_receive(:update_column).with(:last_number_of_players, 0)
      reservation.should_receive(:increment!).with(:inactive_minute_counter)
      ServerNumberOfPlayersWorker.perform_async(reservation.id)
    end

    context "inactive too long" do

      it "ends the reservation" do
        reservation.stub(:server => server)
        reservation.stub(:inactive_too_long? => true)
        reservation.should_receive(:end_reservation)
        ServerNumberOfPlayersWorker.perform_async(reservation.id)
      end

    end

  end


end
