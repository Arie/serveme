require 'spec_helper'

describe Reservation do

  describe '.today' do
    it 'returns reservations for today' do
      yesterday = FactoryGirl.create(:reservation, :date => Date.yesterday)
      today     = FactoryGirl.create(:reservation, :date => Date.today)
      tomorrow  = FactoryGirl.create(:reservation, :date => Date.tomorrow)
      Reservation.today.should == [today]
    end
  end

  describe '.yestertoday' do
    it 'returns reservations for yestertoday' do
      yesterday = FactoryGirl.create(:reservation, :date => Date.yesterday)
      today     = FactoryGirl.create(:reservation, :date => Date.today)
      tomorrow  = FactoryGirl.create(:reservation, :date => Date.tomorrow)
      Reservation.yesterday.should == [yesterday]
    end
  end

  describe "#tv_password" do

    it "should have a default tv_password" do
      subject.tv_password.should == 'tv'
    end

    it 'returns the entered tv_password if available' do
      subject.tv_password = 'tvtvtv'
      subject.tv_password.should == 'tvtvtv'
    end

    it 'returns the default password if the tv_password is an empty string' do
      subject.tv_password = ''
      subject.tv_password.should == 'tv'
    end

  end

  describe '#tv_relaypassword' do

    it "should have a default tv_relaypassword" do
      subject.tv_relaypassword.should == 'tv'
    end

    it 'returns the entered tv_relaypassword if available' do
      subject.tv_relaypassword = 'relay'
      subject.tv_relaypassword.should == 'relay'
    end

    it 'returns the default password if the tv_relaypassword is an empty string' do
      subject.tv_relaypassword = ''
      subject.tv_relaypassword.should == 'tv'
    end

  end

  describe '#date' do
    it 'returns the stored date' do
      reservation = FactoryGirl.create :reservation, :date => Date.yesterday
      reservation.date.should == Date.yesterday
    end

    it 'returns todays date if theres no stored date' do
      subject.date.should == Date.today
    end
  end

  describe '#server_name' do
    it "has the nickname in it" do
      subject.stub(:server).and_return { mock_model(Server, :name => "Server Name") }
      subject.stub(:user).and_return { mock_model(User, :uid => '1234', :nickname => "Nick Name") }
      subject.server_name.should == 'Server Name (Nick Name)'
    end
  end

  describe '#demo_date' do
    it 'formats a date to a stv demo date' do
      subject.stub(:date).and_return { Date.new(2012, 4, 12) }
      subject.demo_date.should == '20120412'
    end
  end

  describe '#log_date' do
    it 'formats a date to a log date' do
      subject.stub(:date).and_return { Date.new(2012, 4, 12) }
      subject.log_date.should == '0412'
    end
  end

  describe '#zipfile_name' do
    it 'generates a unique zipfile name' do
      subject.stub(:user).and_return { mock_model(User, :uid => '1234', :nickname => "Nick Name") }
      subject.stub(:id).and_return { 1 }
      subject.stub(:server_id).and_return { 2 }
      subject.stub(:demo_date).and_return { '3' }
      subject.zipfile_name.should == "1234-1-2-3.zip"
    end
  end

  describe '#end_reservation' do
    it 'should zip demos and logs, remove configuration and destroy itself' do
      subject.should_receive(:zip_demos_and_logs)
      subject.should_receive(:remove_configuration)
      subject.should_receive(:destroy)
      subject.end_reservation
    end
  end

  context "validations" do

    it "verifies the server is reservable by the user" do
      users_group                 = FactoryGirl.create :group,  :name => "User's group"
      other_group                 = FactoryGirl.create :group,  :name => "Not User's group"
      user                        = FactoryGirl.create :user,   :groups => [users_group]
      free_server_other_group     = FactoryGirl.create :server, :groups => [other_group], :name => "free server not in user's group"

      reservation = FactoryGirl.build :reservation, :server => free_server_other_group
      reservation.should have(1).error_on(:server_id)
      reservation.errors.full_messages.should include "Server is not available for you"
    end

    it "verifies the server is free when creating the reservation" do
      users_group                 = FactoryGirl.create :group,  :name => "User's group"
      other_group                 = FactoryGirl.create :group,  :name => "Not User's group"
      user                        = FactoryGirl.create :user,   :groups => [users_group]
      other_user_same_group       = FactoryGirl.create :user,   :groups => [users_group]
      busy_server_in_users_group  = FactoryGirl.create :server, :groups => [users_group], :name => "busy server in user's group"
      FactoryGirl.create :reservation,  :server => busy_server_in_users_group, :user => other_user_same_group

      reservation = FactoryGirl.build :reservation, :server => busy_server_in_users_group, :user => user
      reservation.should have(1).error_on(:server_id)
      reservation.errors.full_messages.should include "Server is no longer available"
    end

    it 'allows user to update reservation' do
      user                        = FactoryGirl.create :user
      reservation                 = FactoryGirl.create :reservation,  :user => user

      reservation.password = 'new password'
      reservation.should have(:no).errors_on(:server_id)
    end

    it "only allows one reservation per user per day" do
      user = FactoryGirl.create :user
      first_reservation     = FactoryGirl.create  :reservation, :user => user, :date => Date.today
      second_reservation    = FactoryGirl.build   :reservation, :user => user, :date => Date.today
      reservation_next_day  = FactoryGirl.build   :reservation, :user => user, :date => Date.tomorrow

      second_reservation.should have(1).error_on(:user_id)
      second_reservation.errors.full_messages.should include "User already made a reservation today"
      reservation_next_day.should be_valid
    end
  end

  describe '#steam_connect_url' do
    it 'returns a steam connect url' do
      subject.stub(:server).and_return { mock_model Server, { :ip => 'fakkelbrigade.eu', :port => '27015'} }
      subject.stub(:password).and_return { "foo" }
      subject.steam_connect_url.should == 'steam://connect/fakkelbrigade.eu:27015/foo'
    end
  end

  describe '#connect_string' do
    it 'returns a console connect string' do
      subject.stub(:server).and_return { mock_model Server, { :ip => 'fakkelbrigade.eu', :port => '27015'} }
      subject.stub(:password).and_return { "foo" }
      subject.connect_string.should == 'connect fakkelbrigade.eu:27015; password foo'
    end
  end


end
