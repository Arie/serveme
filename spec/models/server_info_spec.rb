# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe ServerInfo do
  let(:server) { instance_double(Server, name: 'Name', ip: 'fakkelbrigade.eu', port: '27015', current_rcon: 'foo', id: 1, condenser: SteamCondenser::Servers::SourceServer.stub(:new)) }
  subject do
    described_class.new(server)
  end

  context 'statistics available without rcon' do
    before do
      status = {  server_name: 'Server name',
                  number_of_players: 10,
                  max_players: 20,
                  map_name: 'cp_badlands' }
      subject.stub(status: status)
    end

    describe '#server_name' do
      it 'gets the server_name from the status hash' do
        subject.server_name.should eql 'Server name'
      end

      it 'returns unknown if it cant get the server_name from the hash' do
        subject.status.delete_if { |key| key == :server_name }
        subject.server_name.should eql 'unknown'
      end
    end

    describe '#number_of_players' do
      it 'gets the number_of_players from the status hash' do
        subject.number_of_players.should eql 10
      end

      it 'returns nil if it cant get the number_of_players from the hash' do
        subject.status.delete_if { |key| key == :number_of_players }
        subject.number_of_players.should eql nil
      end
    end

    describe '#max_players' do
      it 'gets the max_players from the status hash' do
        subject.max_players.should eql 20
      end

      it 'returns 0 if it cant get the max_players from the hash' do
        subject.status.delete_if { |key| key == :max_players }
        subject.max_players.should eql 0
      end
    end

    describe '#map_name' do
      it 'gets the map_name from the status hash' do
        subject.map_name.should eql 'cp_badlands'
      end

      it 'returns unknown if it cant get the map_name from the hash' do
        subject.status.delete_if { |key| key == :map_name }
        subject.map_name.should eql 'unknown'
      end
    end
  end

  describe '#auth' do
    it "authenticates with the server's rcon" do
      server = double
      subject.stub(server: server)

      server.should_receive(:rcon_auth)
      subject.auth
    end
  end

  describe '#fetch_rcon_status' do
    it 'auths and uses rcon to get the status' do
      subject.should_receive(:auth)
      server_connection = double
      subject.stub(server_connection: server_connection)
      server_connection.should_receive(:rcon_exec).with('status').and_return ''

      subject.fetch_rcon_status
    end
  end

  context "'rcon stats' statistics" do
    before do
      rcon_stats_output = %|CPU    In (KB/s)  Out (KB/s)  Uptime  Map changes  FPS      Players  Connects
                            24.88  35.29      54.48       6       2            66.67    9        12|
      subject.stub(fetch_stats: rcon_stats_output)
    end

    describe '#stats' do
      it "it creates a hash from the 'rcon stats' output" do
        subject.stats.keys.should =~ %i[cpu in out uptime map_changes fps connects]
      end
    end

    describe '#cpu' do
      it 'returns the server cpu percentage' do
        subject.cpu.should eql '24.88'
      end
    end

    describe '#traffic_in' do
      it 'returns the traffic in KB/s' do
        subject.traffic_in.should eql '35.29'
      end
    end

    describe '#traffic_out' do
      it 'returns the traffic out KB/s' do
        subject.traffic_out.should eql '54.48'
      end
    end

    describe '#uptime' do
      it 'returns the uptime minutes' do
        subject.uptime.should eql '6'
      end
    end

    describe '#map_changes' do
      it 'returns the number of map changes' do
        subject.map_changes.should eql '2'
      end
    end

    describe '#fps' do
      it 'returns the server fps' do
        subject.fps.should eql '66.67'
      end
    end

    describe '#connects' do
      it 'returns the number of player connects' do
        subject.connects.should eql '12'
      end
    end
  end

  describe '#status' do
    before do
      Rails.cache.clear
    end

    it 'gets server info from rcon status' do
      rcon_status_output = %|hostname: FakkelBrigade #1
version : 3032525/24 3032525 secure
udp/ip  : 169.254.61.158:42992  (local: 123.123.123.123:27205)  (public IP from Steam: 123.123.123.123)
steamid : [A:1:3175318537:5985] (90097701101995017)
account : not logged in  (No account specified)
map     : ctf_turbine at: 0 x, 0 y, 0 z
tags    : ctf,increased_maxplayers
sourcetv:  port 27020, delay 30.0s
players : 12 humans, 1 bots (33 max)
edicts  : 532 used of 2048 max
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
Loaded plugins:
---------------------
0:	"TFTrue v4.75, AnAkkk"
---------------------|
      subject.stub(fetch_rcon_status: rcon_status_output)
      subject.server_name.should eql 'FakkelBrigade #1'
      subject.map_name.should eql 'ctf_turbine'
      subject.max_players.should eql 33
      subject.number_of_players.should eql 12
      subject.ip.should eql '169.254.61.158'
      subject.port.should eql 42_992
      subject.version.should eql 3032525
    end

    it 'returns an empty hash if something went wrong' do
      subject.stub(:fetch_rcon_status).and_raise(SteamCondenser::Error.new('BOOM'))

      expect(subject.status).to eql({})
    end
  end

  describe '#fetch_stats' do
    before { Rails.cache.clear }

    it 'gets server info from the rcon based server information' do
      server_connection = double
      subject.stub(server_connection: server_connection)
      server.stub(:rcon_auth)
      server_connection.should_receive(:rcon_exec).with('stats')
      subject.fetch_stats
    end
  end

  describe '#fetch_realtime_stats' do
    let(:server_connection) { double }
    let(:combined_output) do
      <<~OUTPUT
        CPU    In (KB/s)  Out (KB/s)  Uptime  Map changes  FPS      Players  Connects
        24.88  35.29      54.48       6       2            66.67    2        12
        hostname: FakkelBrigade #1
        map     : cp_process_final at: 0 x, 0 y, 0 z
        #{players_line}
        # userid name                uniqueid            connected ping loss state  adr
        #      2 "SourceTV"          BOT                                     active
        #      3 "zeta"              [U:1:1001]          12:34       45    0 active 1.2.3.4:27005
        #      4 "Alpha"             [U:1:1002]          01:02:03    80    3 active 5.6.7.8:27005
        #      5 "Spawning"          [U:1:1003]          00:05       60    0 spawning 9.9.9.9:27005
      OUTPUT
    end
    let(:players_line) { 'players : 3 humans, 1 bots (24 max)' }

    before do
      Rails.cache.clear
      server.stub(:rcon_auth)
      subject.stub(server_connection: server_connection)
      allow(server_connection).to receive(:rcon_exec).with('stats; status').and_return(combined_output)
    end

    it 'combines stats, status and per-player pings from a single rcon call' do
      expect(subject.fetch_realtime_stats).to eq(
        fps: 66.67,
        cpu: 24.88,
        traffic_in: 35.29,
        traffic_out: 54.48,
        player_count: 3,
        player_pings: [
          { name: 'Alpha', ping: 80, loss: 3 },
          { name: 'zeta', ping: 45, loss: 0 }
        ]
      )
      expect(server_connection).to have_received(:rcon_exec).once
    end

    context 'when status has no players line' do
      let(:players_line) { '' }

      it 'counts the active players itself' do
        expect(subject.fetch_realtime_stats[:player_count]).to eq 2
      end
    end

    it 'serves repeat calls from the cache' do
      first = subject.fetch_realtime_stats

      expect(subject.fetch_realtime_stats).to eq first
      expect(server_connection).to have_received(:rcon_exec).once
    end

    context 'when another process holds the lock' do
      before { allow($lock).to receive(:synchronize).and_return(nil) }

      it 'falls back to the stale result' do
        stale = { fps: 1.0, cpu: 2.0, traffic_in: 0, traffic_out: 0, player_count: 1, player_pings: [] }
        Rails.cache.write('realtime_stats_1_stale', stale)

        expect(subject.fetch_realtime_stats).to eq stale
      end

      it 'returns zeroes when nothing is cached' do
        expect(subject.fetch_realtime_stats).to eq(fps: 0, cpu: 0, traffic_in: 0, traffic_out: 0, player_count: 0, player_pings: [])
      end
    end

    it 'logs and re-raises rcon errors' do
      allow(server_connection).to receive(:rcon_exec).and_raise(SteamCondenser::Error.new('BOOM'))
      expect(Rails.logger).to receive(:error).with('Failed to fetch realtime stats: BOOM')

      expect { subject.fetch_realtime_stats }.to raise_error(SteamCondenser::Error)
    end
  end
end
