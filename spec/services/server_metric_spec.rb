require 'spec_helper'

describe ServerMetric do

  let(:rcon_stats_output) { %|CPU   NetIn   NetOut    Uptime  Maps   FPS   Players  Svms    +-ms   ~tick
10.0      11.0      12.0     883     2   127.31       0  243.12    4.45    4.46
L aldkjalsdfj|}

  let(:rcon_status_output) { %q|hostname: KroketBrigade #01 (#13)
version : 1.35.2.7/13527 299/6320 secure  [G:1:248936]
udp/ip  : 5.200.27.206:27315  (public ip: 5.200.27.206)
os      :  Linux
type    :  community dedicated
map     : de_nuke
players : 1 humans, 0 bots (12/0 max) (not hibernating)
#
# userid name uniqueid connected ping loss state rate adr
#  2 1 "Arie - serveme.tf" STEAM_1:0:115851 1:01:50 26 1 active 80000 127.0.0.1:27005
#end
L blablablabla|}

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
    server_statistic.cpu_usage.should == 10
    server_statistic.fps.should == 127

    player_statistic = PlayerStatistic.last
    player_statistic.ping.should == 26
    player_statistic.loss.should == 1
    player_statistic.reservation_player.ip.should == "127.0.0.1"
  end

end
