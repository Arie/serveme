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

  describe '#active?' do
    it 'is active when it is now and provisioned' do
      subject.stub(:now?         => true,
                   :provisioned? => true)
      subject.should be_active
    end
  end

  describe '#now?' do
    it 'is now when current time is between starts and end time' do
      subject.stub(:starts_at    => 1.minute.ago,
                   :ends_at      => 1.minute.from_now)
      subject.should be_now
    end
  end

  describe '#past?' do
    it 'is in the past when the end time is in the past' do
      subject.stub(:ends_at => 1.second.ago)
      subject.should be_past
    end
  end

  describe '#future?' do
    it 'is in the future when the start time is in the future' do
      subject.stub(:starts_at => 1.minute.from_now)
      subject.should be_future
    end
  end

  describe '#duration' do
    it 'calculates duration from start and end times' do
      subject.stub(:starts_at => 1.hour.ago)
      subject.stub(:ends_at   => 1.hour.from_now)
      subject.duration.to_i.should eql (2 * 60 * 60)
    end
  end

  describe '#extend!' do
    it 'allows a user to extend a reservation by 1 hour when the end of the reservation is near' do
      old_reservation_end_time = 10.minutes.from_now
      reservation = create :reservation, :starts_at => 1.hour.ago, :ends_at => old_reservation_end_time, :provisioned => true
      expect{reservation.extend!}.to change{reservation.reload.ends_at}
    end

    it 'does not extend a reservation that hasnt been provisioned yet' do
      old_reservation_end_time = 10.minutes.from_now
      reservation = create :reservation, :starts_at => 1.hour.ago, :ends_at => old_reservation_end_time, :provisioned => false
      expect{reservation.extend!}.not_to change{reservation.reload.ends_at}
    end

    it "does not extend when there's more than an hour left on the reservation" do
      old_reservation_end_time = 61.minutes.from_now
      reservation = create :reservation, :starts_at => 1.hour.ago, :ends_at => old_reservation_end_time, :provisioned => true

      expect{reservation.extend!}.not_to change{reservation.reload.ends_at}
    end
  end

  describe '#end_reservation' do
    it 'should zip demos and logs, remove configuration and destroy itself' do
      subject.stub(:to_s => 'foo')
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

    it "validates the chronologicality of the times" do
      reservation = build :reservation, :starts_at => 1.hour.from_now, :ends_at => 30.minutes.from_now
      reservation.should have(1).error_on(:ends_at)
      reservation.errors.full_messages.should include "Ends at needs to be at least 30 minutes after start time"
    end

    it 'validates the end time is at least 30 minutes after start time' do
      reservation = build :reservation, :starts_at => Time.now, :ends_at => 29.minutes.from_now
      reservation.should have(1).error_on(:ends_at)
      reservation.errors.full_messages.should include "Ends at needs to be at least 30 minutes after start time"

      reservation.ends_at = 30.minutes.from_now
      reservation.should have(:no).errors_on(:ends_at)
    end

    it 'has an initial duration of no more than 3 hours' do
      reservation = build :reservation, :starts_at => Time.now, :ends_at => 181.minutes.from_now
      reservation.should have(1).error_on(:ends_at)
      reservation.errors.full_messages.should include "Ends at maximum reservation time is 3 hours"

      reservation.ends_at = reservation.starts_at + 3.hours
      reservation.should have(:no).errors_on(:ends_at)
    end

    it 'allows extending a reservation past 3 hours' do
      starts = Time.now
      reservation = build :reservation, :starts_at => starts, :ends_at => (starts + 181.minutes)

      reservation.extending = false
      reservation.should have(1).error_on(:ends_at)

      reservation.extending = true
      reservation.should have(:no).errors_on(:ends_at)
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

    describe '#collides?' do
      it 'collides if there are any colliding reservations' do
        subject.stub(:colliding_reservations => ['foo'])
        subject.collides?.should be_true
      end
    end

    describe '#colliding_reservations' do
      it "returns a unique array of collisions with own reservations and other user's reservations" do
        subject.stub(:own_colliding_reservations          => ['foo', 'bar'])
        subject.stub(:other_users_colliding_reservations  => ['foo', 'bar', 'baz'])
        subject.colliding_reservations.should == ['foo', 'bar', 'baz']
      end
    end

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

    describe '#collides_with_own_reservations?' do
      it 'collides with own reservations if there are any' do
        subject.stub(:own_colliding_reservations => ['foo'])
        subject.collides_with_own_reservation?.should be_true
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

    describe '#collides_with_other_users_reservations?' do
      it 'collides with other users reservations if there are any' do
        subject.stub(:other_users_colliding_reservations => ['foo'])
        subject.collides_with_other_users_reservation?.should be_true
      end
    end

  end

end
