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
  let(:rcon_status_output_with_many_players) { %q{hostname: FakkelBrigade #3 (haNfa)
version : 2420080/24 2420080 secure
udp/ip  : 176.9.138.143:27035  (public ip: 176.9.138.143)
steamid : [A:1:3982508037:4686] (90092122746667013)
account : logged in
map     : cp_process_final at: 0 x, 0 y, 0 z
sourcetv:  port 27040, delay 90.0s
players : 12 humans, 1 bots (25 max)
edicts  : 1147 used of 2048 max
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
#      3 "Kaptain Küle #LikeGodButReal" [U:1:114333916] 03:04   62    0 active 77.102.238.82:62724
#      4 "Valikund"          [U:1:29822948]      03:04       56    0 active 152.66.218.161:27005
#      5 "disturbia"         [U:1:78553810]      03:03       73    0 active 77.123.113.235:27005
#      6 "meth0d mix fam"    [U:1:129741393]     03:02       75    0 active 80.41.137.239:27005
#      7 "SENS LOW AS MY IQ" [U:1:71652445]      03:02       90    0 active 90.181.25.86:27005
#      9 "metsöö#army"     [U:1:101863002]     02:39      142    3 active 88.195.103.227:27005
#     10 "Ti-Ta-Thoomsn"     [U:1:74807277]      02:38       68    0 active 88.117.83.179:27005
#     11 "Control.Couscout"  [U:1:80902379]      02:32       52   77 spawning 109.212.23.82:27005
#     12 "☁TTT☁ TechSandvich" [U:1:128676262] 02:31     174    0 active 202.177.225.44:5586
#     13 "haNfa"             [U:1:79879120]      02:19      100    0 active 78.62.161.197:27005
#     14 "cc//kurwen"        [U:1:97094821]      02:15       71    0 active 81.190.146.90:27005
#     15 "sOur"              [U:1:45375518]      02:01       72    0 active 88.222.114.25:27005
Loaded plugins:
---------------------
0:	"TFTrue v4.63, AnAkkk"
---------------------} }

  let(:playing_over_an_hour) { %q{
# userid name                uniqueid            connected ping loss state  adr
#      2 "SourceTV"          BOT                                     active
#      4 "Lupus"             [U:1:58880794]       1:24:34    80    0 active 130.204.219.90:27005
#      9 "h3x"               [U:1:56594558]       1:12:58    97    0 active 85.107.17.57:27005
#      6 "Buttnose"          [U:1:16733858]       1:23:57    61    0 active 94.192.59.71:59018
#      7 "Raptor | TF2Pickup.net" [U:1:91169800]  1:22:22    71    0 active 80.123.6.127:49441
#      8 "nyxgrandkillah"    [U:1:58889462]       1:20:46    69    0 active 88.201.142.16:27005
#     10 "[M] Nadir"         [U:1:31923277]       1:11:25    56    0 active 188.63.130.208:27005
#     11 "zooooob"           [U:1:27416040]       1:10:52    87    0 active 84.248.100.46:27005
#     12 "kaidus"            [U:1:3048631]        1:09:42    59    0 active 86.2.59.49:27005
#     13 "Übersexuals :3 Mirelin" [U:1:37008225]  1:08:51   78    0 active 46.109.163.177:27005
#     14 "^.^"               [U:1:88662301]       1:08:38    55    0 active 85.27.163.7:27005
#     15 "Shifty"            [U:1:53210756]       1:06:31    70    0 active 188.99.211.225:27008
#     16 "Thalash!"          [U:1:103786523]      1:05:37    69    0 active 93.167.11.208:27005
#     17 "Dave_ `S funny lessons" [U:1:38202343] 55:09      142    0 active 67.184.78.225:27005

              } }
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

    it "creates many player objects" do
      r = RconStatusParser.new(rcon_status_output_with_many_players)
      r.players.size.should == 12
    end

    it "handles players that have been connected for over an hour" do
      r = RconStatusParser.new(playing_over_an_hour)
      r.players.size.should == 13
    end

  end
end
