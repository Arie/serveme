# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe ServerMetric do
  let(:rcon_stats_output) do
    %|CPU    In (KB/s)  Out (KB/s)  Uptime  Map changes  FPS      Players  Connects
24.88  35.29      54.48       6       2            66.67    17        21|
  end

  let(:rcon_status_output) do
    'hostname: BlackOut Gaming #5 (Jakov)
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
#      4 "TNT-DEAD"          [U:1:51245596]      11:49       57    0 active 1.128.0.1:4597
#      5 "Bloodyyy"          [U:1:50924149]      00:49       76    1 active 1.128.0.2:27005
Loaded plugins:
---------------------
0:      "TFTrue v4.63, AnAkkk"
---------------------'
  end

  let(:reservation) { create :reservation }
  let(:server) { double :server, id: reservation.server_id, current_reservation: reservation, condenser: double }
  let(:server_info_hash) { { number_of_players: 1, map_name: 'cp_granlands' } }
  let(:server_info) { ServerInfo.new(server) }

  before do
    server_info.stub(status: server_info_hash,
                     fetch_stats: rcon_stats_output,
                     fetch_rcon_status: rcon_status_output)
  end

  it 'creates server and player statistics' do
    ServerMetric.new(server_info)

    expect(PlayerStatistic.count).to eql 2
    expect(ServerStatistic.count).to eql 1
    server_statistic = ServerStatistic.last
    server_statistic.cpu_usage.should == 25
    server_statistic.fps.should == 67

    player_statistic = PlayerStatistic.last
    player_statistic.ping.should == 76
    player_statistic.loss.should == 1
    player_statistic.reservation_player.ip.should == '1.128.0.2'
  end

  it 'kicks VPN players using numeric user ID' do
    ReservationPlayer.should_receive(:banned_asn_ip?).with('1.128.0.1').twice.and_return(true)
    ReservationPlayer.should_receive(:whitelisted_uid?).with(76561198011511324).and_return(false)
    server.should_receive(:rcon_exec).with('kickid 4 [localhost] Please play without VPN; addip 0 1.128.0.1')

    ReservationPlayer.should_receive(:banned_asn_ip?).with('1.128.0.2').and_return(false)
    ReservationPlayer.should_receive(:whitelisted_uid?).with(76561198011189877).and_return(false)

    ServerMetric.new(server_info)
  end

  it 'kicks banned players with proper command order and ban reason' do
    ReservationPlayer.should_receive(:banned_asn_ip?).with('1.128.0.1').and_return(false)
    ReservationPlayer.should_receive(:whitelisted_uid?).with(76561198011511324).and_return(false)
    ReservationPlayer.should_receive(:banned_uid?).with(76561198011511324).twice.and_return('Cheating')
    server.should_receive(:rcon_exec).with('kickid 4 Cheating; banid 0 [U:1:51245596]; addip 0 1.128.0.1')

    ReservationPlayer.should_receive(:banned_asn_ip?).with('1.128.0.2').and_return(false)
    ReservationPlayer.should_receive(:whitelisted_uid?).with(76561198011189877).and_return(false)
    ReservationPlayer.should_receive(:banned_uid?).with(76561198011189877).and_return(false)
    ReservationPlayer.should_receive(:banned_ip?).with('1.128.0.2').and_return(false)

    ServerMetric.new(server_info)
  end

  describe 'SDR player handling in firewall_allow_players' do
    let(:rcon_status_with_sdr) do
      'hostname: Test Server
version : 2406664/24 2406664 secure
udp/ip  : 109.70.149.21:27055  (public ip: 109.70.149.21)
steamid : [A:1:251166723:4677] (90092080360620035)
map     : koth_pro_viaduct_rc4 at: 0 x, 0 y, 0 z
players : 2 humans, 0 bots (25 max)

# userid name                uniqueid            connected ping loss state  adr
#      3 "SDRPlayer"         [U:1:12345678]      11:49       57    0 active 169.254.1.1:27005
#      4 "NormalPlayer"      [U:1:87654321]      00:49       76    1 active 1.128.0.1:4597'
    end

    before do
      server_info.stub(status: server_info_hash,
                       fetch_stats: rcon_stats_output,
                       fetch_rcon_status: rcon_status_with_sdr)
      reservation.stub(:allow_reservation_player)
      reservation.stub(:server).and_return(server)
      server.stub(:supports_mitigations?).and_return(true)
    end

    it 'enqueues profile check for SDR player, kicks if no normal IP, marks as whitelisted but does not firewall whitelist' do
      sdr_steam_uid = 76561197972611406
      normal_steam_uid = 76561198047920049

      # Stub banned player checks for both players
      ReservationPlayer.should_receive(:whitelisted_uid?).with(sdr_steam_uid).at_least(:once).and_return(false)
      ReservationPlayer.should_receive(:whitelisted_uid?).with(normal_steam_uid).at_least(:once).and_return(false)
      ReservationPlayer.should_receive(:banned_uid?).with(sdr_steam_uid).and_return(false)
      ReservationPlayer.should_receive(:banned_uid?).with(normal_steam_uid).and_return(false)
      ReservationPlayer.should_receive(:banned_ip?).with('169.254.1.1').and_return(false)
      ReservationPlayer.should_receive(:banned_ip?).with('1.128.0.1').and_return(false)
      ReservationPlayer.should_receive(:banned_asn_ip?).with('169.254.1.1').and_return(false)
      ReservationPlayer.should_receive(:banned_asn_ip?).with('1.128.0.1').and_return(false)

      # SDR player checks
      expect(CheckSdrSteamProfileWorker).to receive(:perform_async).with(kind_of(Integer))
      ReservationPlayer.should_receive(:sdr_eligible_steam_profile?).with(sdr_steam_uid).and_return(false)
      server.should_receive(:rcon_exec).with('kickid 3 Please connect normally before joining with SDR; addip 1 169.254.1.1')

      # Normal player should get firewall whitelisted
      expect(reservation).to receive(:allow_reservation_player) do |rp|
        expect(rp.steam_uid).to eq(normal_steam_uid.to_s)
        expect(rp.ip).to eq('1.128.0.1')
      end

      ServerMetric.new(server_info)

      # Verify SDR player was marked as whitelisted but not firewall whitelisted
      sdr_rp = ReservationPlayer.find_by(steam_uid: sdr_steam_uid, ip: '169.254.1.1')
      expect(sdr_rp.whitelisted).to be true
    end

    it 'does not kick SDR player if they have normal IP history' do
      sdr_steam_uid = 76561197972611406
      normal_steam_uid = 76561198047920049

      # Stub banned player checks for both players
      ReservationPlayer.should_receive(:whitelisted_uid?).with(sdr_steam_uid).at_least(:once).and_return(false)
      ReservationPlayer.should_receive(:whitelisted_uid?).with(normal_steam_uid).at_least(:once).and_return(false)
      ReservationPlayer.should_receive(:banned_uid?).with(sdr_steam_uid).and_return(false)
      ReservationPlayer.should_receive(:banned_uid?).with(normal_steam_uid).and_return(false)
      ReservationPlayer.should_receive(:banned_ip?).with('169.254.1.1').and_return(false)
      ReservationPlayer.should_receive(:banned_ip?).with('1.128.0.1').and_return(false)
      ReservationPlayer.should_receive(:banned_asn_ip?).with('169.254.1.1').and_return(false)
      ReservationPlayer.should_receive(:banned_asn_ip?).with('1.128.0.1').and_return(false)

      # SDR player checks
      expect(CheckSdrSteamProfileWorker).to receive(:perform_async).with(kind_of(Integer))
      ReservationPlayer.should_receive(:sdr_eligible_steam_profile?).with(sdr_steam_uid).and_return(true)
      server.should_not_receive(:rcon_exec).with(/kickid 3/)

      ServerMetric.new(server_info)
    end

    it 'skips SDR player if they are globally whitelisted' do
      sdr_steam_uid = 76561197972611406
      normal_steam_uid = 76561198047920049

      # SDR player is globally whitelisted, so skip all checks
      ReservationPlayer.should_receive(:whitelisted_uid?).with(sdr_steam_uid).at_least(:once).and_return(true)
      ReservationPlayer.should_receive(:whitelisted_uid?).with(normal_steam_uid).at_least(:once).and_return(false)
      ReservationPlayer.should_receive(:banned_uid?).with(normal_steam_uid).and_return(false)
      ReservationPlayer.should_receive(:banned_ip?).with('1.128.0.1').and_return(false)
      ReservationPlayer.should_receive(:banned_asn_ip?).with('1.128.0.1').and_return(false)

      expect(CheckSdrSteamProfileWorker).not_to receive(:perform_async)
      server.should_not_receive(:rcon_exec).with(/kickid 3/)

      ServerMetric.new(server_info)
    end

    it 'does not re-check SDR player if already marked as whitelisted' do
      sdr_steam_uid = 76561197972611406
      normal_steam_uid = 76561198047920049

      # Create player already marked as whitelisted
      create(:reservation_player, reservation: reservation, steam_uid: sdr_steam_uid, ip: '169.254.1.1', whitelisted: true)

      # Still need to stub checks for ban detection and normal player
      ReservationPlayer.should_receive(:whitelisted_uid?).with(sdr_steam_uid).at_least(:once).and_return(false)
      ReservationPlayer.should_receive(:banned_uid?).with(sdr_steam_uid).and_return(false)
      ReservationPlayer.should_receive(:banned_ip?).with('169.254.1.1').and_return(false)
      ReservationPlayer.should_receive(:banned_asn_ip?).with('169.254.1.1').and_return(false)
      ReservationPlayer.should_receive(:whitelisted_uid?).with(normal_steam_uid).at_least(:once).and_return(false)
      ReservationPlayer.should_receive(:banned_uid?).with(normal_steam_uid).and_return(false)
      ReservationPlayer.should_receive(:banned_ip?).with('1.128.0.1').and_return(false)
      ReservationPlayer.should_receive(:banned_asn_ip?).with('1.128.0.1').and_return(false)

      expect(CheckSdrSteamProfileWorker).not_to receive(:perform_async)
      server.should_not_receive(:rcon_exec).with(/kickid 3/)

      ServerMetric.new(server_info)
    end
  end
end
