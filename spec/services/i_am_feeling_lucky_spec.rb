require 'spec_helper'

describe IAmFeelingLucky do

  let(:user) { create :user }
  subject { IAmFeelingLucky.new(user) }

  context "without a previous reservation" do

    it "finds an available server and builds a reservation" do
      available_server = create :server

      reservation = subject.build_reservation

      reservation.server.should == available_server
      reservation.rcon.should be_an Integer
      reservation.password.should be_an Integer
      reservation.tv_password.should be_an Integer
      reservation.auto_end.should be true
    end

  end

  context "with a previous reservation" do

    it "tries to make a reservation with same settings and server again" do
      previous_reservation = create :reservation, :user => user, :rcon => "the_rcon"
      previous_reservation.update_column(:ends_at, 1.hour.ago)

      reservation = subject.build_reservation

      reservation.server.should == previous_reservation.server
      reservation.rcon.should == previous_reservation.rcon
    end

    it "falls back to a server on the same host" do
      previous_reservation = create :reservation, :user => user, :rcon => "the_rcon"
      previous_reservation.update_column(:starts_at, 2.hours.ago)
      previous_reservation.update_column(:ends_at,   1.hour.ago)
      new_reservation_taking_my_previous_server = create :reservation, :server => previous_reservation.server
      fallback_server_on_same_host = create :server, :ip => previous_reservation.server.ip, :port => 1337
      some_other_server = create(:server, :ip => "foo.bar")

      reservation = subject.build_reservation

      reservation.server.should == fallback_server_on_same_host
    end

    it "falls back to a server in the same location if all on host are taken" do
      previous_reservation = create :reservation, :user => user, :rcon => "the_rcon"
      previous_reservation.update_column(:starts_at, 2.hours.ago)
      previous_reservation.update_column(:ends_at,   1.hour.ago)
      new_reservation_taking_my_previous_server = create :reservation, :server => previous_reservation.server
      fallback_server_on_same_host              = create :server, :ip => previous_reservation.server.ip, :port => 1337
      new_reservation_taking_fallback_server    = create :reservation, :server => fallback_server_on_same_host

      fallback_server_in_same_location  = create(:server, :ip => "2.2.2.2", :location_id => previous_reservation.server.location_id)
      fallback_server_in_other_location = create(:server, :ip => "3.3.3.3", :location_id => create(:location))

      reservation = subject.build_reservation

      reservation.server.should == fallback_server_in_same_location
    end

    it "falls back to any available server in case the rest is taken" do
      previous_reservation = create :reservation, :user => user, :rcon => "the_rcon"
      previous_reservation.update_column(:starts_at, 2.hours.ago)
      previous_reservation.update_column(:ends_at,   1.hour.ago)
      new_reservation_taking_my_previous_server = create :reservation, :server => previous_reservation.server

      some_fallback_server = create :server, :location_id => create(:location), :ip => "3.3.3.3"

      reservation = subject.build_reservation

      reservation.server.should == some_fallback_server
    end

  end

end

