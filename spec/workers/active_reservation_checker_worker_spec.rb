require 'spec_helper'

describe ActiveReservationCheckerWorker do

  let(:reservation) { create :reservation }
  before do
    server_info = double(:server_info, number_of_players: 1).as_null_object
    server = double(:server, server_info: server_info)
    reservation.should_receive(:server).and_return(server)
    allow(ServerMetric).to receive(:new)
    Reservation.should_receive(:find).with(reservation.id).and_return(reservation)
  end

  it "finds the server to check" do
    server = double(:server, :occupied? => true, :number_of_players => 1)
    reservation.should_receive(:server).at_least(:once).and_return(server)
    ActiveReservationCheckerWorker.perform_async(reservation.id)
  end

  context "occupied server" do

    let(:server) { double(:server, :occupied? => true, :number_of_players => 1) }

    it "saves the number of players and resets the inactive minutes" do
      reservation.stub(:server => server)

      reservation.should_receive(:update_column).with(:last_number_of_players,  1)
      reservation.should_receive(:update_column).with(:inactive_minute_counter, 0)
      ActiveReservationCheckerWorker.perform_async(reservation.id)
    end

  end

  context "unoccupied server" do

    let(:server) { double(:server, :occupied? => false, :number_of_players => 0) }
    before { reservation.stub(:server => server) }

    it "saves the number of players and resets the inactive minutes" do

      reservation.should_receive(:update_column).with(:last_number_of_players, 0)
      reservation.should_receive(:increment!).with(:inactive_minute_counter)
      ActiveReservationCheckerWorker.perform_async(reservation.id)
    end

    context "inactive too long" do

      context "not a TF2Center reservation" do

        it "ends the reservation and increases the user's expired reservations counter" do
          user = double(:user)
          user.should_receive(:increment!).with(:expired_reservations)
          reservation.stub(:server => server)
          reservation.stub(:user   => user)
          reservation.stub(:inactive_too_long? => true)
          reservation.stub(:tf2center? => false)
          reservation.should_receive(:end_reservation)
          ActiveReservationCheckerWorker.perform_async(reservation.id)
        end

      end

    end

    context "auto end reservation" do

      it "ends the reservation if server becomes empty after 30 minutes" do
        reservation.starts_at = 31.minutes.ago
        reservation.last_number_of_players = 1
        reservation.should_receive(:end_reservation)
        ActiveReservationCheckerWorker.perform_async(reservation.id)
      end

      it "doesn't end the reservation if it's more recent" do
        reservation.starts_at = 29.minutes.ago
        reservation.last_number_of_players = 1
        reservation.should_not_receive(:end_reservation)
        ActiveReservationCheckerWorker.perform_async(reservation.id)
      end

      it "doesn't end the reservation if it wasn't occupied before" do
        reservation.starts_at = 31.minutes.ago
        reservation.last_number_of_players = 0
        reservation.should_not_receive(:end_reservation)
        ActiveReservationCheckerWorker.perform_async(reservation.id)
      end

    end

  end


end
