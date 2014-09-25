require 'spec_helper'

describe RconStatusParser do

  let(:rcon_status_output)  { %q{hostname: BlackOut Gaming #5 (Jakov)
version : 2406664/24 2406664 secure
udp/ip  : 109.70.149.21:27055  (public ip: 109.70.149.21)
steamid : [A:1:251166723:4677] (90092080360620035)
account : not logged in  (No account specified)
map     : koth_pro_viaduct_rc4 at: 0 x, 0 y, 0 z
sourcetv:  port 27060, delay 90.0s
players : 17 humans, 1 bots (25 max)
edicts  : 478 used of 2048 max
        Spawns Points Kills Deaths Assists
Scout         0      0     0      0       0
Sniper        0      0     0      0       0
Soldier       0      0     0      0       0
Demoman       0      0     0      0       0
Medic         0      0     0      0       0
Heavy         0      0     0      0       0
Pyro          0      0     0      0       0
Spy           0      0     0      0       0
Engineer      0      0     0      0       0

# userid name                uniqueid            connected ping loss state  adr
#      2 "SourceTV"          BOT                                     active
#      4 "TNT-DEAD"          [U:1:51245596]      11:49       57    0 active 111.111.111.111:4597
#      5 "Bloodyyy"          [U:1:50924149]      00:49       76    1 active 222.222.222.222:27005
Loaded plugins:
---------------------
0:      "TFTrue v4.63, AnAkkk"
---------------------} }

  describe "#players" do

    it "creates player objects" do
      r = RconStatusParser.new(rcon_status_output)
      r.players.size.should == 2

      p1 = r.players.first
      p1.name.should == "TNT-DEAD"
      p1.ping.should == 57
      p1.loss.should == 0
      p1.should be_active
      p1.should be_relevant

      p2 = r.players.last
      p2.name.should == "Bloodyyy"
      p2.ping.should == 76
      p2.loss.should == 1
      p2.should be_active
      p2.should_not be_relevant
    end

  end
end
