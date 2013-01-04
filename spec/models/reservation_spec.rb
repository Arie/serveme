require 'spec_helper'

describe Reservation do

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

  describe '#server_name' do
    it "has the nickname in it" do
      subject.stub(:server).and_return { mock_model(Server, :name => "Server Name") }
      subject.stub(:user).and_return { mock_model(User, :uid => '1234', :nickname => "Nick Name") }
      subject.server_name.should == 'Server Name (Nick Name)'
    end
  end

  describe '#demo_date' do
    it 'formats a date to a stv demo date' do
      subject.stub(:starts_at).and_return { DateTime.new(2012, 4, 12) }
      subject.demo_date.should == '20120412'
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
      subject.end_reservation
    end
  end

  context "validations" do

    it "verifies the server is reservable by the user" do
      users_group                 = create :group,  :name => "User's group"
      other_group                 = create :group,  :name => "Not User's group"
      user                        = create :user,   :groups => [users_group]
      free_server_other_group     = create :server, :groups => [other_group], :name => "free server not in user's group"

      reservation = build :reservation, :server => free_server_other_group
      reservation.should have(1).error_on(:server_id)
      reservation.errors.full_messages.should include "Server is not available for you"
    end

    it 'allows user to update reservation' do
      user                        = create :user
      reservation                 = create :reservation,  :user => user

      reservation.password = 'new password'
      reservation.should have(:no).errors_on(:server_id)
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

  context 'finding collisions' do
    describe '#own_colliding_reservations' do
      it "finds colliding reservations from its user" do
        user    = create(:user)
        reservation       = create(:reservation,  :user => user, :starts_at => Time.now,             :ends_at => 1.hour.from_now)
        front_overlap     = build(:reservation,   :user => user, :starts_at => 10.minutes.ago,       :ends_at => 50.minutes.from_now)
        internal          = build(:reservation,   :user => user, :starts_at => 10.minutes.from_now,  :ends_at => 50.minutes.from_now)
        rear_overlap      = build(:reservation,   :user => user, :starts_at => 55.minutes.from_now,  :ends_at => 2.hours.from_now)
        complete_overlap  = build(:reservation,   :user => user, :starts_at => 10.minutes.ago,       :ends_at => 2.hours.from_now)

        front_overlap.own_colliding_reservations.should == [reservation]
        rear_overlap.own_colliding_reservations.should == [reservation]
        complete_overlap.own_colliding_reservations.should == [reservation]
        internal.own_colliding_reservations.should == [reservation]
      end
    end

    describe '#other_users_colliding_reservations' do
      it "finds colliding reservations from its server" do
        server  = create(:server)
        reservation       = create(:reservation,  :server => server, :starts_at => Time.now,             :ends_at => 1.hour.from_now)
        front_overlap     = build(:reservation,   :server => server, :starts_at => 10.minutes.ago,       :ends_at => 50.minutes.from_now)
        internal          = build(:reservation,   :server => server, :starts_at => 10.minutes.from_now,  :ends_at => 50.minutes.from_now)
        rear_overlap      = build(:reservation,   :server => server, :starts_at => 55.minutes.from_now,  :ends_at => 2.hours.from_now)
        complete_overlap  = build(:reservation,   :server => server, :starts_at => 10.minutes.ago,       :ends_at => 2.hours.from_now)

        front_overlap.other_users_colliding_reservations.should == [reservation]
        rear_overlap.other_users_colliding_reservations.should == [reservation]
        complete_overlap.other_users_colliding_reservations.should == [reservation]
        internal.other_users_colliding_reservations.should == [reservation]
      end
    end

  end

end
