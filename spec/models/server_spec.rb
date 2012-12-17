require 'spec_helper'

describe Server do

  describe '#reserved_today_by' do

    it 'knows if a user reserved that server today' do
      user = FactoryGirl.create :user
      not_reserved_by_user  = FactoryGirl.create :server
      reserved_by_user      = FactoryGirl.create :server

      FactoryGirl.create :reservation, :server => reserved_by_user, :user => user

      reserved_by_user.reserved_today_by?(user).should == true
      not_reserved_by_user.reserved_today_by?(user).should == false
    end

  end

  describe '.already_reserved_today' do

    it "should return servers with reservations for today" do
      free_server = FactoryGirl.create :server, :name => "free today"
      busy_server = FactoryGirl.create :server, :name => "busy today"
      reservation = FactoryGirl.create :reservation, :server => busy_server
      Server.already_reserved_today.should == [busy_server]
    end

  end

  describe '.groupless_available_today' do

    it "should find servers without groups that aren't reserved yet" do
      groupless_free_server   = FactoryGirl.create :server, :name => "groupless free"
      groupless_busy_server   = FactoryGirl.create :server, :name => "groupless busy"
      reservation             = FactoryGirl.create :reservation, :server => groupless_busy_server
      grouped_server          = FactoryGirl.create :server, :name => "grouped"
      grouped_server.groups << FactoryGirl.create(:group)
      Server.groupless_available_today.should =~ [groupless_free_server]
    end

  end

  describe '.with_group' do

    it 'should find servers in a group' do
      group       = FactoryGirl.create :group, :name => "Great group"
      other_group = FactoryGirl.create :group, :name => "Other group"
      server_in_group     = FactoryGirl.create :server, :groups => [group], :name => "server in group"
      server_not_in_group = FactoryGirl.create :server, :name => "server in no groups"
      server_other_group  = FactoryGirl.create :server, :groups => [other_group], :name => "server other group"

      Server.with_group.should =~ [server_in_group, server_other_group]
    end

  end

  describe '.in_groups' do

    it 'should find servers belonging to a certain group' do
      group       = FactoryGirl.create :group, :name => "Great group"
      other_group = FactoryGirl.create :group, :name => "Other group"
      server_in_group     = FactoryGirl.create :server, :groups => [group], :name => "server in group"
      server_not_in_group = FactoryGirl.create :server, :name => "server in no groups"
      server_other_group  = FactoryGirl.create :server, :name => "server other group", :groups => [other_group]

      Server.in_groups([group]).should == [server_in_group]
    end

    it 'should only return servers once even with multiple matching groups' do
      group       = FactoryGirl.create :group, :name => "Great group"
      group2      = FactoryGirl.create :group, :name => "Great group 2"
      other_group = FactoryGirl.create :group, :name => "Other group"
      server_in_group     = FactoryGirl.create :server, :groups => [group, group2], :name => "server in group"
      server_not_in_group = FactoryGirl.create :server, :name => "server in no groups"
      server_other_group  = FactoryGirl.create :server, :name => "server other group", :groups => [other_group]

      Server.in_groups([group, group2]).should == [server_in_group]
    end

  end

  describe '.reservable_by_user' do

    it "returns servers in the users group and servers without groups regardless of reservations" do
      users_group                 = FactoryGirl.create :group,  :name => "User's group"
      other_group                 = FactoryGirl.create :group,  :name => "Not User's group"
      user                        = FactoryGirl.create :user,   :groups => [users_group]
      free_server_in_users_group  = FactoryGirl.create :server, :groups => [users_group], :name => "free server in user's group"
      busy_server_in_users_group  = FactoryGirl.create :server, :groups => [users_group], :name => "busy server in user's group"
      free_server_other_group     = FactoryGirl.create :server, :groups => [other_group], :name => "free server not in user's group"
      free_server_no_group        = FactoryGirl.create :server, :groups => []
      busy_server_no_group        = FactoryGirl.create :server, :groups => []
      FactoryGirl.create :reservation, :server => busy_server_in_users_group, :user => user
      FactoryGirl.create :reservation, :server => busy_server_no_group

      Server.reservable_by_user(user).should =~ [free_server_in_users_group, busy_server_in_users_group, free_server_no_group, busy_server_no_group]
    end

  end

  describe '.available_today_for_user' do

    it "returns empty servers in the users group and empty servers without groups" do
      users_group                 = FactoryGirl.create :group,  :name => "User's group"
      other_group                 = FactoryGirl.create :group,  :name => "Not User's group"
      user                        = FactoryGirl.create :user,   :groups => [users_group]
      free_server_in_users_group  = FactoryGirl.create :server, :groups => [users_group], :name => "free server in user's group"
      busy_server_in_users_group  = FactoryGirl.create :server, :groups => [users_group], :name => "busy server in user's group"
      free_server_other_group     = FactoryGirl.create :server, :groups => [other_group], :name => "free server not in user's group"
      free_server_no_group        = FactoryGirl.create :server, :groups => []
      FactoryGirl.create :reservation, :server => busy_server_in_users_group, :user => user

      Server.available_today_for_user(user).should =~ [free_server_in_users_group, free_server_no_group]
    end

  end

  describe '#restart' do

    it "sends the software termination signal to the process" do
      subject.should_receive(:process_id).at_least(:once).and_return { 1337 }
      Process.should_receive(:kill).with(15, 1337)
      subject.restart
    end

  end

end
