require 'spec_helper'

describe LogWorker do

  let(:user)                  { create :user, :uid => '76561197960497430' }
  let(:server)                { double(:server, :id => 1, :rcon_auth => true, :condenser => condenser).as_null_object }
  let(:condenser)             { double.as_null_object }
  let(:reservation)           { create :reservation, :user => user, :logsecret => '1234567' }
  let(:extend_line)           { '1234567L 03/29/2014 - 13:15:53: "Arie - serveme.tf<3><[U:1:231702]><Red>" say "!extend"' }
  let(:troll_line)            { '1234567L 03/29/2014 - 13:15:53: "TRoll<3><[U:0:1337]><Red>" say "!end"' }
  let(:end_line)              { '1234567L 03/29/2014 - 13:15:53: "Arie - serveme.tf<3><[U:1:231702]><Red>" say "!end"' }
  let(:rcon_changelevel_line) { '1234567L 03/29/2014 - 13:15:53: "Arie - serveme.tf<3><[U:1:231702]><Red>" say "!rcon changelevel cp_badlands"' }
  let(:rcon_empty_line)       { '1234567L 03/29/2014 - 13:15:53: "Arie - serveme.tf<3><[U:1:231702]><Red>" say "!rcon"' }
  let(:rcon_with_quotes_line) { '1234567L 03/29/2014 - 13:15:53: "Arie - serveme.tf<3><[U:1:231702]><Red>" say "!rcon mp_tournament "1""' }
  let(:rate_line)             { '1234567L 03/29/2014 - 13:15:53: "Troll<3><[U:1:12345]><Red>" say "!rate bad laggy piece of shit"' }
  let(:empty_rate_line)       { '1234567L 03/29/2014 - 13:15:53: "Troll<3><[U:1:12345]><Red>" say "!rate "' }
  let(:wrong_rate_line)       { '1234567L 03/29/2014 - 13:15:53: "Troll<3><[U:1:12345]><Red>" say "!rate foobar"' }
  subject(:logworker) { LogWorker.perform_async(line) }

  before do
    allow(Server).to receive(:find).with(anything).and_return(server)
    Rails.cache.clear
    Reservation.should_receive(:includes).at_least(:once).with(:user).and_return(Reservation)
    Reservation.should_receive(:find).at_least(:once).with(reservation.id).and_return(reservation)
    reservation.stub(:server => server)
  end

  describe "ending reservation" do

    it "triggers the end worker" do
      server.should_receive(:rcon_say)
      ReservationWorker.should_receive(:perform_async).with(reservation.id, "end")
      LogWorker.perform_async(end_line)
    end

    it "doesn't trigger when someone else tries to end" do
      server.should_not_receive(:rcon_say)
      ReservationWorker.should_not_receive(:perform_async).with(reservation.id, "end")
      LogWorker.perform_async(troll_line)
    end

  end

  describe "extending reservation" do

    it "triggers extension directly and notifies the server" do
      reservation.should_receive(:extend!).and_return(true)
      server.should_receive(:rcon_say)
      LogWorker.perform_async(extend_line)
    end

    it "notifies when extension wasn't possible" do
      reservation.should_receive(:extend!).and_return(false)
      server.should_receive(:rcon_say).with("Couldn't extend your reservation: you can only extend when there's less than 1 hour left and no one else has booked the server.")
      LogWorker.perform_async(extend_line)
    end

  end

  describe "rcon" do

    it "doesn't do anything without a command" do
      server.should_not_receive(:rcon_exec)
      LogWorker.perform_async(rcon_empty_line)
    end

    it "executes rcon commands" do
      server.should_receive(:rcon_exec).with("changelevel cp_badlands")
      LogWorker.perform_async(rcon_changelevel_line)
    end

    it "is not afraid of quotes in the commands" do
      server.should_receive(:rcon_exec).with('mp_tournament "1"')
      LogWorker.perform_async(rcon_with_quotes_line)
    end

  end

  describe "rating servers" do

    it "saves the rating" do
      LogWorker.perform_async(rate_line)
      Rating.count.should == 1
      rating = Rating.last
      rating.reservation.should == reservation
      rating.nickname.should == "Troll"
      rating.steam_uid.should == "76561197960278073"
    end

    it "informs the player the rating was saved" do
      server.should_receive(:rcon_say).with("Thanks for rating this server Troll")
      LogWorker.perform_async(rate_line)
    end

    it "ignores invalid ratings" do
      LogWorker.perform_async(wrong_rate_line)
      Rating.count.should == 0

      LogWorker.perform_async(empty_rate_line)
      Rating.count.should == 0
    end

  end

end
