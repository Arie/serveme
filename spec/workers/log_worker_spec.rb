require 'spec_helper'

describe LogWorker do

  let(:user)                  { create :user, :uid => '76561197960497430' }
  let(:server)                { double(:server, :id => 1, :rcon_auth => true, :condenser => condenser).as_null_object }
  let(:condenser)             { double.as_null_object }
  let(:reservation)           { create :reservation, :user => user, :logsecret => '1234567' }
  let(:extend_line)           { '1234567L 03/29/2014 - 13:15:53: "Arie - serveme.tf<3><[U:1:231702]><Red>" say "!extend"' }
  let(:lobby_extend_line)     { '1234567L 03/29/2014 - 13:15:53: "Lobby player<3><[U:1:1337]><Red>" say "!extend"' }
  let(:troll_line)            { '1234567L 03/29/2014 - 13:15:53: "TRoll<3><[U:0:1337]><Red>" say "!end"' }
  let(:end_line)              { '1234567L 03/29/2014 - 13:15:53: "Arie - serveme.tf<3><[U:1:231702]><Red>" say "!end"' }
  let(:rcon_changelevel_line) { '1234567L 03/29/2014 - 13:15:53: "Arie - serveme.tf<3><[U:1:231702]><Red>" say "!rcon changelevel cp_badlands"' }
  let(:rcon_empty_line)       { '1234567L 03/29/2014 - 13:15:53: "Arie - serveme.tf<3><[U:1:231702]><Red>" say "!rcon"' }
  let(:rcon_with_quotes_line) { '1234567L 03/29/2014 - 13:15:53: "Arie - serveme.tf<3><[U:1:231702]><Red>" say "!rcon mp_tournament "1""' }
  let(:timeleft_line)         { '1234567L 03/29/2014 - 13:15:53: "Troll<3><[U:1:12345]><Red>" say "!timeleft"' }
  let(:who_line)              { '1234567L 03/29/2014 - 13:15:53: "Troll<3><[U:1:12345]><Red>" say "!who"' }
  let(:who_troll)             { '1234567L 03/29/2014 - 19:15:53: "BindTroll<3><[U:1:12344]><Red>" say "!who is the best"' }
  let(:turbine_start_line)    { '1234567L 02/07/2015 - 20:39:40: Started map "ctf_turbine" (CRC "a7e226a1ff6dd4b8d546d7d341d446dc")' }
  let(:badlands_start_line)   { '1234567L 02/07/2015 - 20:39:40: Started map "cp_badlands" (CRC "a7e226a1ff6dd4b8d546d7d341d446dc")' }
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
      server.should_receive(:rcon_say).with(/Extended/)
      LogWorker.perform_async(extend_line)
    end

    it "allows any player in a lobby to extend" do
      reservation.should_receive(:extend!).and_return(true)
      reservation.stub(:lobby? => true)
      server.should_receive(:rcon_say).with(/Extended/)
      LogWorker.perform_async(lobby_extend_line)
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

  describe "recognizing server start" do

    context "turbine" do
      it "saves a status indicating the server started and will change again" do
        LogWorker.perform_async(turbine_start_line)
        ReservationStatus.last.status.should include("switching map")
      end
    end

    context "other map" do
      it "saves a status indicating the server has started the map" do
        LogWorker.perform_async(badlands_start_line)
        ReservationStatus.last.status.should include("cp_badlands")
      end
    end

  end

  describe "timeleft" do

    it "returns the time left in words for the reservation" do
      server.should_receive(:rcon_say).with(/Reservation time left: \d+ minutes/)
      LogWorker.perform_async(timeleft_line)
    end

  end

  describe "who" do

    it "returns the name of the reserver for the reservation" do
      server.should_receive(:rcon_say).with("Reservation created by: '#{reservation.user.name}'")
      LogWorker.perform_async(who_line)
    end
    
    it "should not return if there is text before or after the command" do
      server.should_not_receive(:rcon_say)
      ReservationWorker.should_not_receive(:perform_async).with("Reservation created by: '#{reservation.user.name}'")
      LogWorker.perform_async(who_troll)
    end

  end

end
