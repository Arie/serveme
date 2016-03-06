require 'spec_helper'

describe ServerInfo do

  let(:server) { double(:name => "Name", :ip => 'fakkelbrigade.eu', :port => '27015', :current_rcon => 'foo', :id => 1, :condenser => SteamCondenser::Servers::SourceServer.stub(:new)) }
  subject do
    described_class.new(server)
  end

  context 'statistics available without rcon' do

    before do
      status = {  :server_name        => "Server name",
                  :number_of_players  => '10',
                  :max_players        => '20',
                  :map_name           => 'cp_badlands' }
      subject.stub(:status => status)
    end

    describe "#server_name" do
      it 'gets the server_name from the status hash' do
        subject.server_name.should eql "Server name"
      end

      it 'returns unknown if it cant get the server_name from the hash' do
        subject.status.delete_if {|key| key == :server_name }
        subject.server_name.should eql 'unknown'
      end
    end

    describe "#number_of_players" do
      it 'gets the number_of_players from the status hash' do
        subject.number_of_players.should eql "10"
      end

      it 'returns nil if it cant get the number_of_players from the hash' do
        subject.status.delete_if {|key| key == :number_of_players }
        subject.number_of_players.should eql nil
      end
    end

    describe "#max_players" do
      it 'gets the max_players from the status hash' do
        subject.max_players.should eql "20"
      end

      it 'returns 0 if it cant get the max_players from the hash' do
        subject.status.delete_if {|key| key == :max_players }
        subject.max_players.should eql '0'
      end
    end

    describe "#map_name" do
      it 'gets the map_name from the status hash' do
        subject.map_name.should eql "cp_badlands"
      end

      it 'returns unknown if it cant get the map_name from the hash' do
        subject.status.delete_if {|key| key == :map_name }
        subject.map_name.should eql 'unknown'
      end
    end

  end

  describe '#auth' do
    it "authenticates with the server's rcon" do
      server = double
      subject.stub(:server => server)

      server.should_receive(:rcon_auth)
      subject.auth
    end
  end

  describe "#get_rcon_status" do

    it "auths and uses rcon to get the status" do
      subject.should_receive(:auth)
      server_connection = double
      subject.stub(:server_connection => server_connection)
      server_connection.should_receive(:rcon_exec).with("status").and_return ""

      subject.get_rcon_status
    end

  end


  context "'rcon stats' statistics" do

    before do
      rcon_stats_output = %|CPU   NetIn   NetOut    Uptime  Maps   FPS   Players  Svms    +-ms   ~tick
  10.0      11.0      12.0     883     2   10.00       0  243.12    4.45    4.46|
      subject.stub(:get_stats => rcon_stats_output)
    end

    describe '#stats' do

      it "it creates a hash from the 'rcon stats' output" do
        subject.stats.keys.should =~ [:cpu, :in, :out, :uptime, :map_changes, :fps]
      end

    end

    describe '#cpu' do

      it 'returns the server cpu percentage' do
        subject.cpu.should eql '10.0'
      end

    end

    describe '#traffic_in' do

      it 'returns the traffic in KB/s' do
        subject.traffic_in.should eql '11.0'
      end

    end

    describe '#traffic_out' do

      it 'returns the traffic out KB/s' do
        subject.traffic_out.should eql '12.0'
      end

    end

    describe '#uptime' do

      it 'returns the uptime minutes' do
        subject.uptime.should eql '883'
      end

    end

    describe '#map_changes' do

      it 'returns the number of map changes' do
        subject.map_changes.should eql '2'
      end

    end

    describe '#fps' do

      it 'returns the server fps' do
        subject.fps.should eql '10.00'
      end

    end

  end

  describe '#status' do

    before do
      Rails.cache.clear
    end

    it "gets server info from rcon status" do
      rcon_status_output = %|hostname: KroketBrigade #01
version : 1.35.2.7/13527 299/6320 secure  [G:1:248936]
udp/ip  : 5.200.27.206:27315  (public ip: 5.200.27.206)
os      :  Linux
type    :  community dedicated
map     : de_dust2
players : 4 humans, 0 bots (12/0 max) (hibernating)

# userid name uniqueid connected ping loss state rate adr
#end|
      subject.stub(:get_rcon_status => rcon_status_output)
      subject.server_name.should eql "KroketBrigade #01"
      subject.map_name.should eql "de_dust2"
      subject.max_players.should eql "12"
      subject.number_of_players.should eql 4
    end

    it "returns an empty hash if something went wrong" do
      subject.stub(:get_rcon_status).and_raise(SteamCondenser::Error.new("BOOM"))

      expect(subject.status).to eql({})
    end

  end

  describe '#get_stats' do

    before { Rails.cache.clear }

    it "gets server info from the rcon based server information" do
      server_connection = double
      subject.stub(:server_connection => server_connection)
      server.stub(:rcon_auth)
      server_connection.should_receive(:rcon_exec).with('stats')
      subject.get_stats
    end

  end

end
