require 'spec_helper'

describe Server do

  describe '.with_group' do

    it 'should find servers in a group' do
      group       = create :group, :name => "Great group"
      other_group = create :group, :name => "Other group"
      server_in_group     = create :server, :groups => [group], :name => "server in group"
      server_not_in_group = create :server, :name => "server in no groups"
      server_other_group  = create :server, :groups => [other_group], :name => "server other group"

      Server.with_group.should =~ [server_in_group, server_other_group]
    end

  end

  describe '.in_groups' do

    it 'should find servers belonging to a certain group' do
      group       = create :group, :name => "Great group"
      other_group = create :group, :name => "Other group"
      server_in_group     = create :server, :groups => [group], :name => "server in group"
      server_not_in_group = create :server, :name => "server in no groups"
      server_other_group  = create :server, :name => "server other group", :groups => [other_group]

      Server.in_groups([group]).should == [server_in_group]
    end

    it 'should only return servers once even with multiple matching groups' do
      group       = create :group, :name => "Great group"
      group2      = create :group, :name => "Great group 2"
      other_group = create :group, :name => "Other group"
      server_in_group     = create :server, :groups => [group, group2], :name => "server in group"
      server_not_in_group = create :server, :name => "server in no groups"
      server_other_group  = create :server, :name => "server other group", :groups => [other_group]

      Server.in_groups([group, group2]).should == [server_in_group]
    end

  end

  describe '.reservable_by_user' do

    it "returns servers in the users group and servers without groups regardless of reservations" do
      users_group                 = create :group,  :name => "User's group"
      other_group                 = create :group,  :name => "Not User's group"
      user                        = create :user,   :groups => [users_group]
      free_server_in_users_group  = create :server, :groups => [users_group], :name => "free server in user's group"
      busy_server_in_users_group  = create :server, :groups => [users_group], :name => "busy server in user's group"
      free_server_other_group     = create :server, :groups => [other_group], :name => "free server not in user's group"
      free_server_no_group        = create :server, :groups => []
      busy_server_no_group        = create :server, :groups => []
      create :reservation, :server => busy_server_in_users_group, :user => user
      create :reservation, :server => busy_server_no_group

      Server.reservable_by_user(user).should =~ [free_server_in_users_group, busy_server_in_users_group, free_server_no_group, busy_server_no_group]
    end

  end

  describe '#restart' do

    it "sends the software termination signal to the process" do
      subject.should_receive(:process_id).at_least(:once).and_return { 1337 }
      Process.should_receive(:kill).with(15, 1337)
      subject.restart
    end

    it "logs an error when it couldn't find the process id" do
      logger = stub
      subject.stub(:logger).and_return { logger }
      subject.should_receive(:process_id).at_least(:once).and_return { nil }
      Process.should_not_receive(:kill)

      logger.should_receive(:error)

      subject.restart
    end

  end

  describe '#find_process_id' do
    it 'picks the correct pid from the list' do
      correct_process = './srcds_linux -game tf -port 27015 -autoupdate +ip 176.9.138.143 +maxplayers 24 +map ctf_turbine -tickrate 66 +tv_port 27020 +tv_maxclients 32 +tv_enable 1"'
      other_processes = ["/bin/sh ./srcds_run -ip 176.9.138.143 -game tf -console +tv_maxclients 255 +exec relay.cfg +tv_port 27100 +tv_relay relay.vanillatv.org:27100 +password +tv_autorecord 1",
                         "./srcds_linux -ip 176.9.138.143 -game tf -console +tv_maxclients 255 +exec relay.cfg +tv_port 27100 +tv_relay relay.vanillatv.org:27100 +password +tv_autorecord 1",
                         "SCREEN -AmdS tf2-4 ./srcds_run -game tf -port 27045 -autoupdate +ip 176.9.138.143 +maxplayers 24 +map ctf_turbine -tickrate 66 +tv_port 27050 +tv_maxclients 32 +tv_enable 1 +exec server.cfg",
                         "/bin/sh ./srcds_run -game tf -port 27045 -autoupdate +ip 176.9.138.143 +maxplayers 24 +map ctf_turbine -tickrate 66 +tv_port 27050 +tv_maxclients 32 +tv_enable 1 +exec server.cfg",
                         "SCREEN -AmdS webrelay ./srcds_run -ip 176.9.138.143 -game tf -console +tv_maxclients 255 +exec relay.cfg +tv_port 27100 +tv_relay 176.9.138.143:27030 +password tv +tv_autorecord 1",
                         "/bin/sh ./srcds_run -ip 176.9.138.143 -game tf -console +tv_maxclients 255 +exec relay.cfg +tv_port 27100 +tv_relay 176.9.138.143:27030 +password tv +tv_autorecord 1",
                         "./srcds_linux -ip 176.9.138.143 -game tf -console +tv_maxclients 255 +exec relay.cfg +tv_port 27100 +tv_relay 176.9.138.143:27030 +password tv +tv_autorecord 1",
                         "./srcds_linux -game tf -port 27025 -autoupdate +ip 176.9.138.143 +maxplayers 24 +map ctf_turbine -tickrate 66 +tv_port 27030 +tv_maxclients 32 +tv_enable 1"]
      processes = []
      other_processes.each_with_index do |process, index|
        processes << stub(:cmdline => process, :pid => 2000 + index)
      end
      processes << stub(:cmdline => correct_process, :pid => 1337)
      Sys::ProcTable.should_receive(:ps).and_return(processes)

      subject.stub(:port => '27015')
      subject.process_id.should == 1337
    end
  end

  describe '#tf_dir' do

    it "takes the server's path and adds the TF2 dirs" do
      subject.stub(:path => '/foo/bar')
      subject.tf_dir.should == '/foo/bar/orangebox/tf'
    end

  end

  describe '#current_reservation' do

    it 'returns nil if there is no reservation active on the server' do
      server = create(:server)
      server.current_reservation.should == nil
    end

    it 'gives the current reservation if there is one' do
      server      = create(:server)
      reservation = create(:reservation, :starts_at => 1.minute.ago, :ends_at => 1.hour.from_now, :server => server)

      server.current_reservation.should == reservation
    end

  end

  describe '#current_rcon' do

    it "gives the normal rcon if there's no reservation active" do
      subject.stub(:rcon => 'the rcon')
      subject.current_rcon.should == 'the rcon'
    end

    it "gives the rcon of the current reservation if there is one" do
      subject.stub(:current_reservation => mock_model(Reservation, :rcon => 'foo'))
      subject.stub(:rcon => 'bar')
      subject.current_rcon.should == 'foo'
    end

  end

  describe "#remove_configuration" do

    before do
      @tf_dir       = Rails.root.join('tmp')
      @config_file  = @tf_dir.join('cfg', 'reservation.cfg').to_s
    end
    it 'deletes the reservation.cfg if its available' do
      subject.stub(:tf_dir => @tf_dir)

      File.should_receive(:exists?).with(@config_file).and_return(true)
      File.should_receive(:delete).with(@config_file)
      subject.remove_configuration
    end

    it 'does not explode when there is no reservation.cfg' do
      subject.stub(:tf_dir => @tf_dir)

      File.should_receive(:exists?).with(@config_file).and_return(false)
      File.should_not_receive(:delete).with(@config_file)
      subject.remove_configuration
    end
  end

end
