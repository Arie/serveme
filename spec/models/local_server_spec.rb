# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe LocalServer do
  describe '.with_group' do
    it 'should find servers in a group' do
      group       = create :group, name: 'Great group'
      other_group = create :group, name: 'Other group'
      server_in_group = create :server, groups: [ group ], name: 'server in group'
      server_not_in_group = create :server, name: 'server in no groups'
      server_other_group  = create :server, groups: [ other_group ], name: 'server other group'

      Server.with_group.should =~ [ server_in_group, server_other_group ]
    end
  end

  describe '.active' do
    it 'returns active servers' do
      active_server   = create :server, name: 'Active'
      inactive_server = create :server, name: 'Inactive', active: false
      Server.active.should == [ active_server ]
    end
  end

  describe '.member_of_groups' do
    it 'should find servers belonging to a certain group' do
      group       = create :group, name: 'Great group'
      other_group = create :group, name: 'Other group'
      server_in_group = create :server, groups: [ group ], name: 'server in group'
      server_not_in_group = create :server, name: 'server in no groups'
      server_other_group  = create :server, name: 'server other group', groups: [ other_group ]

      Server.member_of_groups(Group.where(id: group.id)).should eq [ server_in_group ]
    end

    it 'should only return servers once even with multiple matching groups' do
      group       = create :group, name: 'Great group'
      group2      = create :group, name: 'Great group 2'
      other_group = create :group, name: 'Other group'
      server_in_group = create :server, groups: [ group, group2 ], name: 'server in group'
      server_not_in_group = create :server, name: 'server in no groups'
      server_other_group  = create :server, name: 'server other group', groups: [ other_group ]

      Server.member_of_groups(Group.where(id: [ group.id, group2.id ])).should eq [ server_in_group ]
    end
  end

  describe '.ordered' do
    it 'orders by position and name' do
      fourth  = create :server, position: 3, name: 'AB'
      second  = create :server, position: 1, name: 'A1'
      first   = create :server, position: 1, name: 'A0'
      third   = create :server, position: 2, name: 'B0'

      Server.ordered.should == [ first, second, third, fourth ]
    end
  end

  describe '.reservable_by_user' do
    it 'returns servers in the users group and servers without groups regardless of reservations' do
      users_group                 = create :group,  name: "User's group"
      other_group                 = create :group,  name: "Not User's group"
      user                        = create :user
      user.groups << users_group
      free_server_in_users_group = create :server, name: "free server in user's group"
      free_server_in_users_group.groups << users_group
      busy_server_in_users_group = create :server, name: "busy server in user's group"
      busy_server_in_users_group.groups << users_group
      free_server_other_group = create :server, name: "free server not in user's group"
      free_server_other_group.groups << other_group
      free_server_no_group        = create :server
      busy_server_no_group        = create :server
      create :reservation, server: busy_server_in_users_group, user: user
      create :reservation, server: busy_server_no_group

      Server.reservable_by_user(user).should =~ [ free_server_in_users_group, busy_server_in_users_group, free_server_no_group, busy_server_no_group ]
    end
  end

  describe '#start_reservation' do
    it 'updates the configuration and triggers a restart', :vcr do
      reservation = stubbed_reservation(enable_plugins?: true, enable_mitigations: true)
      subject.should_receive(:restart)
      subject.should_receive(:enable_plugins)
      subject.should_receive(:add_sourcemod_admin)
      subject.should_receive(:add_sourcemod_servers)
      subject.should_receive(:update_configuration).with(reservation)
      subject.start_reservation(reservation)
    end

    it 'writes a config file', :vcr do
      reservation = stubbed_reservation(id: 1337, password: 'secret', enable_plugins?: false, enable_mitigations: true, disable_democheck?: false)
      subject.should_receive(:restart)
      file = double
      subject.stub(tf_dir: '/tmp')

      rgl_base_cfg_content = File.read(Rails.root.join('doc', 'rgl_base.cfg'))
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(Rails.root.join('doc', 'rgl_base.cfg')).and_return(rgl_base_cfg_content)

      expect(File).to receive(:write).with('/tmp/cfg/reservation.cfg', 'config file contents').ordered.and_return(file)
      expect(File).to receive(:write).with('/tmp/cfg/ctf_turbine.cfg', 'config file contents').ordered.and_return(file)
      expect(File).to receive(:write).with('/tmp/cfg/rgl_base.cfg', rgl_base_cfg_content).ordered.and_return(file)
      expect(File).to receive(:write).with('/tmp/motd.txt', 'http://localhost:3000/reservations/1337/motd?password=secret').ordered.and_return(file)

      subject.should_receive(:generate_config_file).exactly(2).times.with(reservation, anything).and_return('config file contents')
      subject.start_reservation(reservation)
    end
  end

  describe '#write_custom_whitelist' do
    it 'takes a whitelist and writes it to the server dir' do
      reservation = double(custom_whitelist_id: 1337)
      reservation.stub(custom_whitelist_content: 'foobar')

      subject.stub(tf_dir: '/tmp')
      subject.should_receive(:write_configuration).with('/tmp/cfg/custom_whitelist_1337.txt', 'foobar')

      subject.write_custom_whitelist(reservation)
    end
  end

  describe '#end_reservation' do
    subject { described_class.new(path: '/tmp/test_server_path') }

    it 'should zip demos and logs, remove configuration and restart' do
      reservation_id = 1
      StacLogsDownloaderWorker.should_receive(:perform_async).with(reservation_id).and_return nil
      reservation = double(id: reservation_id, rcon: 'foo', status: 'Ready', status_update: nil, ended?: false, reload: true, user: nil)
      subject.should_receive(:copy_logs)
      subject.should_receive(:zip_demos_and_logs).with(reservation)
      subject.should_receive(:disable_plugins)
      subject.should_receive(:disable_demos_tf)
      subject.should_receive(:remove_logs_and_demos)
      subject.should_receive(:remove_configuration)
      subject.should_receive(:rcon_exec).once
      subject.should_receive(:restart)
      subject.should_receive(:rcon_disconnect)
      subject.end_reservation(reservation)
    end
  end

  describe '#update_reservation' do
    it 'should only update the configuration' do
      reservation = double
      subject.should_receive(:update_configuration)
      subject.update_reservation(reservation)
    end
  end

  describe '#restart' do
    it 'sends the software termination signal to the process' do
      subject.should_receive(:process_id).at_least(:once).and_return(1337)
      Process.should_receive(:kill).with(15, 1337)
      subject.restart
    end

    it "logs an error when it couldn't find the process id" do
      logger = double
      subject.stub(:logger).and_return(logger)
      subject.should_receive(:process_id).at_least(:once).and_return(nil)
      Process.should_not_receive(:kill)

      logger.should_receive(:error)

      subject.restart
    end
  end

  describe '#tf_dir' do
    it "takes the server's path and adds the TF2 dirs" do
      subject.stub(path: '/foo/bar')
      subject.tf_dir.should eql '/foo/bar/tf'
    end
  end

  describe '#demos' do
    it 'uses a Dir glob to get the demos' do
      subject.stub(demo_match: 'foo')
      Dir.should_receive(:glob).with('foo').and_return([])
      subject.demos
    end
  end

  describe '#logs' do
    it 'uses a Dir glob to get the logs' do
      subject.stub(log_match: 'bar')
      Dir.should_receive(:glob).with('bar').and_return([])
      subject.logs
    end
  end

  describe '#log_copier_class' do
    it 'returns the log copier class' do
      subject.log_copier_class.should eql(LocalLogCopier)
    end
  end

  describe '#zip_file_creator_class' do
    it 'returns the zip file creator class' do
      subject.zip_file_creator_class.should eql(LocalZipFileCreator)
    end
  end

  describe '#current_reservation' do
    it 'returns nil if there is no reservation active on the server' do
      server = create(:server)
      server.current_reservation.should eql nil
    end

    it 'gives the current reservation if there is one' do
      server      = create(:server)
      reservation = create(:reservation, starts_at: 1.minute.ago, ends_at: 1.hour.from_now, server: server)

      server.current_reservation.should eql reservation
    end
  end

  describe '#current_rcon' do
    it "gives the normal rcon if there's no reservation active" do
      subject.stub(rcon: 'the rcon')
      subject.current_rcon.should eql 'the rcon'
    end

    it 'gives the rcon of the current reservation if there is one' do
      subject.stub(current_reservation: mock_model(Reservation, rcon: 'foo', provisioned?: true))
      subject.stub(rcon: 'bar')
      subject.current_rcon.should eql 'foo'
    end
  end

  describe '#occupied?' do
    it "is occupied when there's more than 0 players" do
      ServerInfo.should_receive(:new).with(subject).and_return(double(number_of_players: 1))
      subject.should be_occupied
    end

    it 'defaults to true when something went wrong updating the player number' do
      ServerInfo.should_receive(:new).with(subject).and_raise(SteamCondenser::Error::Timeout)
      subject.should be_occupied
    end
  end

  describe '#remove_configuration' do
    before do
      @tf_dir       = Rails.root.join('tmp')
      @config_file  = @tf_dir.join('cfg', 'reservation.cfg').to_s
      @map_file     = @tf_dir.join('cfg', 'ctf_turbine.cfg').to_s
      @ban_id_file  = @tf_dir.join('cfg', 'banned_user.cfg').to_s
      @ban_ip_file  = @tf_dir.join('cfg', 'banned_ip.cfg').to_s
      @motd_file    = @tf_dir.join('motd.txt').to_s
    end
    it 'deletes the reservation.cfg if its available' do
      subject.stub(tf_dir: @tf_dir)

      FileUtils.should_receive(:rm_rf).with(@config_file)
      FileUtils.should_receive(:rm_rf).with(@map_file)
      FileUtils.should_receive(:rm_rf).with(@ban_id_file)
      FileUtils.should_receive(:rm_rf).with(@ban_ip_file)
      FileUtils.should_receive(:rm_rf).with(@motd_file)
      subject.remove_configuration
    end
  end

  describe '#inactive_minutes' do
    it 'shows the inactive minutes from the current reservation' do
      subject.stub(current_reservation: double(inactive_minute_counter: 10))
      subject.inactive_minutes.should eql 10
    end

    it 'is 0 if there is no current reservation' do
      subject.stub(current_reservation: nil)
      subject.inactive_minutes.should eql 0
    end
  end

  describe '#copy_to_server' do
    it 'uses a simple local copy' do
      files = %w[foo bar]
      destination = 'destination'
      subject.should_receive('system').with('cp foo bar destination')
      subject.copy_to_server(files, destination)
    end
  end

  describe '#list_files' do
    it 'takes the globbed files and returns just the basename' do
      complete_filepaths = [ '/foo/bar/baz.bsp', '/foo/bar/qux.txt' ]
      subject.stub(tf_dir: 'foo')
      dir = 'bar'
      Dir.should_receive(:glob).with(File.join(subject.tf_dir, dir, '*')).and_return(complete_filepaths)

      subject.list_files('bar').should == [ 'baz.bsp', 'qux.txt' ]
    end
  end

  describe '#remove_logs_and_demos' do
    it 'removes the logs and demos from disk' do
      subject.stub(logs: [ double ])
      subject.stub(demos: [ double ])
      files = subject.logs + subject.demos
      FileUtils.should_receive(:rm).with(files)
      subject.remove_logs_and_demos
    end
  end

  describe '#condenser' do
    it 'creates a steam condenser to the server' do
      subject.stub(ip: 'fakkelbrigade.eu', port: '27015')
      SteamCondenser::Servers::SourceServer.should_receive(:new).with('fakkelbrigade.eu', 27_015)
      subject.condenser
    end
  end

  describe '#rcon_auth' do
    it 'sends the current rcon to the condenser' do
      condenser = double
      subject.stub(condenser: condenser, current_rcon: 'foobar')
      condenser.should_receive(:rcon_auth).with('foobar')
      subject.rcon_auth
    end
  end

  describe '#rcon_say' do
    let(:message)       { 'Hello world!' }
    let(:condenser)     { double }
    let(:current_rcon)  { double }

    before do
      subject.stub(condenser: condenser, current_rcon: current_rcon)
      condenser.should_receive(:rcon_auth).with(current_rcon).and_return(true)
    end

    it 'delivers a message with rcon say to the server' do
      condenser.should_receive(:rcon_exec).with("say #{message}")
      subject.rcon_say(message)
    end

    it 'logs an error if something went wrong' do
      condenser.should_receive(:rcon_exec).and_raise(SteamCondenser::Error::Timeout)
      logger = double
      Rails.stub(logger: logger)
      logger.should_receive(:error).with(anything)
      subject.rcon_say 'foobar'
    end
  end

  describe 'server version' do
    let(:condenser)     { double }
    let(:current_rcon)  { double }
    let(:version_info)  do
      %(Build Label:           5257084   # Uniquely identifies each build
Network PatchVersion:  5257083   # Determines client and server compatibility
Protocol version:           24   # High level network protocol version
Server version:        5257084
Server AppID:           232250%)
    end

    before do
      subject.stub(condenser: condenser, current_rcon: current_rcon)
      condenser.should_receive(:rcon_auth).with(current_rcon).and_return(true)
    end

    it 'parses the server version from the rcon response' do
      condenser.should_receive(:rcon_exec).with('version').and_return(version_info)
      subject.version.should == 5_257_083
    end

    it 'knows if the server is outdated', :vcr do
      condenser.should_receive(:rcon_exec).with('version').and_return(version_info)
      subject.should be_outdated
    end
  end

  describe '#enable_plugins' do
    it 'writes the sourcemod.vdf to the server' do
      subject.should_receive(:path).at_least(:once).and_return('foo')
      subject.should_receive(:write_configuration).with(subject.sourcemod_file, anything)
      subject.enable_plugins
    end
  end

  describe '#enable_demos_tf' do
    it 'writes the demostf.smx to the server' do
      subject.stub(tf_dir: 'tf_dir')
      subject.should_receive(:copy_to_server).with(anything, "#{subject.tf_dir}/addons/sourcemod/plugins")
      subject.enable_demos_tf
    end
  end

  describe '#tv_port' do
    it 'defaults to the server port + 5' do
      subject.stub(port: 1000)
      subject.tv_port.should eql 1005
    end
    it 'uses its own value if it is set' do
      subject.tv_port = 1001
      subject.tv_port.should eql 1001
    end
  end

  describe '#blocked_command?' do
    it 'knows blocked commands' do
      subject.blocked_command?('logaddress_add 123.123.123.123:4567').should be true
    end

    it 'doesnt block allowed commands' do
      subject.blocked_command?('exec etf2l.cfg').should be false
    end
  end

  private

  define_method(:stubbed_reservation) do |stubs = {}|
    reservation = instance_double(Reservation, first_map: nil, custom_whitelist_id: false, status_update: instance_double(ReservationStatus), enable_plugins?: false, enable_demos_tf?: false, user: build(:user), server: build(:server), disable_democheck?: false)
    allow(reservation).to receive_messages(stubs) if stubs.any?
    reservation
  end
end
