require 'spec_helper'

describe RconStatusParser do

  let(:rcon_status_output) { %q|hostname: KroketBrigade #01 (#13)
version : 1.35.2.7/13527 299/6320 secure  [G:1:248936]
udp/ip  : 5.200.27.206:27315  (public ip: 5.200.27.206)
os      :  Linux
type    :  community dedicated
map     : de_nuke
players : 1 humans, 0 bots (12/0 max) (not hibernating)

# userid name uniqueid connected ping loss state rate adr
#  2 1 "Arie - serveme.tf" STEAM_1:0:115851 02:00 26 1 active 80000 127.0.0.1:27005|}
                             #
  let(:playing_over_an_hour) { %q|hostname: KroketBrigade #01 (#13)
version : 1.35.2.7/13527 299/6320 secure  [G:1:248936]
udp/ip  : 5.200.27.206:27315  (public ip: 5.200.27.206)
os      :  Linux
type    :  community dedicated
map     : de_nuke
players : 1 humans, 0 bots (12/0 max) (not hibernating)

# userid name uniqueid connected ping loss state rate adr
#  2 1 "Arie - serveme.tf" STEAM_1:0:115851 1:01:50 26 1 active 80000 127.0.0.1:27005
L alflaflalfl| }
                               #
  describe "#players" do

    it "creates player objects" do
      r = RconStatusParser.new(rcon_status_output)
      r.players.size.should == 1

      p1 = r.players.first
      p1.name.should == "Arie - serveme.tf"
      p1.ping.should == 26
      p1.loss.should == 1
      p1.should be_active
      p1.should be_relevant

    end

    it "handles players that have been connected for over an hour" do
      r = RconStatusParser.new(playing_over_an_hour)
      r.players.size.should == 1
      r.players.map(&:minutes_connected).should eql [61]
    end

  end
end
