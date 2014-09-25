require 'spec_helper'

describe ServerMetric do

  let(:rcon_stats_output) { %|CPU    In (KB/s)  Out (KB/s)  Uptime  Map changes  FPS      Players  Connects
24.88  35.29      54.48       6       2            66.67    17        21|}

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

  let(:reservation) { create :reservation }
  let(:server) { double :server, :id => reservation.server_id, :current_reservation => reservation, :condenser => double }
  let(:server_info_hash) { { :number_of_players => 1, :map_name => "cp_granlands" } }
  let(:server_info) { ServerInfo.new(server) }

  before do
    server_info.stub( :status => server_info_hash,
                      :get_stats => rcon_stats_output,
                      :get_rcon_status => rcon_status_output)
  end

  it "creates server and player statistics" do
    ServerMetric.new(server_info)

    expect(PlayerStatistic.count).to eql 1
    expect(ServerStatistic.count).to eql 1
    server_statistic = ServerStatistic.last
    server_statistic.cpu_usage.should == 25
    server_statistic.fps.should == 67

    player_statistic = PlayerStatistic.last
    player_statistic.ping.should == 57
    player_statistic.loss.should == 0
  end

end
