# frozen_string_literal: true

require 'spec_helper'

describe Reservation do
  context 'with a custom whitelist' do
    it 'saves a new custom whitelist from whitelist.tf' do
      request = double(body: 'the whitelist', success?: true)
      connection = double
      connection.should_receive(:get).with(anything).and_return(request)
      Faraday.should_receive(:new).with(anything).and_return(connection)
      reservation = build(:reservation, custom_whitelist_id: 103)
      reservation.valid?
      WhitelistTf.find_by_tf_whitelist_id(103).content.should == 'the whitelist'
    end

    it 'updates the whitelist' do
      request = double(body: '104 the whitelist', success?: true)
      connection = double
      connection.should_receive(:get).with(anything).and_return(request)
      Faraday.should_receive(:new).with(anything).and_return(connection)
      reservation = create :reservation

      reservation.custom_whitelist_id = 104
      reservation.valid?

      WhitelistTf.find_by_tf_whitelist_id(104).content.should == '104 the whitelist'
    end

    it "sets an error if the whitelist couldn't be downloaded" do
      reservation = build(:reservation, custom_whitelist_id: 103)
      Faraday.should_receive(:new).with(anything).and_raise(Faraday::Error::ClientError.new('foo'))
      reservation.should have(1).error_on(:custom_whitelist_id)
    end
  end

  describe 'passwords' do
    it 'wont allow passwords that are too long' do
      too_long = 'a' * 61
      just_right = 'b' * 60

      reservation = build(:reservation)

      reservation.password = too_long
      reservation.should have(1).error_on(:password)

      reservation.password = just_right
      reservation.should have(:no).error_on(:password)
    end

    it 'wont allow passwords with invalid characters' do
      valid_chars = "azAZ0123456789!@-\ #$^&*/()_+}'|\\:<>?,.[]"
      invalid_chars = ['"', '💩', ';', '%']

      reservation = build(:reservation)

      valid_pw = 'A' * 10

      valid_chars.chars.each do |char|
        reservation.password = "#{valid_pw}#{char}"
        reservation.should have(:no).error_on(:password)
      end

      invalid_chars.each do |char|
        reservation.password = "#{valid_pw}#{char}"
        reservation.should have(1).error_on(:password)
      end
    end
  end

  describe '#tv_password' do
    it 'should have a default tv_password' do
      subject.tv_password.should eql 'tv'
    end

    it 'returns the entered tv_password if available' do
      subject.tv_password = 'tvtvtv'
      subject.tv_password.should eql 'tvtvtv'
    end

    it 'returns the default password if the tv_password is an empty string' do
      subject.tv_password = ''
      subject.tv_password.should eql 'tv'
    end
  end

  describe '#tv_relaypassword' do
    it 'should have a default tv_relaypassword' do
      subject.tv_relaypassword.should eql 'tv'
    end

    it 'returns the entered tv_relaypassword if available' do
      subject.tv_relaypassword = 'relay'
      subject.tv_relaypassword.should eql 'relay'
    end

    it 'returns the default password if the tv_relaypassword is an empty string' do
      subject.tv_relaypassword = ''
      subject.tv_relaypassword.should eql 'tv'
    end
  end

  describe '#server_name' do
    it 'has the nickname in it' do
      subject.stub(:server).and_return(mock_model(Server, name: 'Server Name'))
      subject.stub(:id).and_return(1337)
      subject.server_name.should eql "#{SITE_HOST} (#1337)"
    end
  end

  describe '#zipfile_name' do
    it 'generates a unique zipfile name' do
      subject.stub(:user).and_return(mock_model(User, uid: '1234', nickname: 'Nick Name'))
      subject.stub(:id).and_return(1)
      subject.stub(:server_id).and_return(2)
      subject.stub(:formatted_starts_at).and_return('3')
      subject.stub(:starts_at).and_return(Time.now)
      subject.zipfile_name.should eql '1234-1-2-3.zip'
    end
  end

  describe '#formattted_starts_at' do
    it 'uses the UTC time' do
      starts_at = Time.now.utc
      subject.stub(:starts_at).and_return(starts_at)
      month_number = format('%02d', starts_at.month)
      day_number = format('%02d', starts_at.day)
      subject.formatted_starts_at.should == "#{starts_at.year}#{month_number}#{day_number}"
    end
  end

  describe '#active?' do
    it 'is active when it is now and provisioned' do
      subject.stub(now?: true,
                   provisioned?: true)
      subject.should be_active
    end
  end

  describe '#now?' do
    it 'is now when current time is between starts and end time' do
      subject.stub(starts_at: 1.minute.ago,
                   ends_at: 1.minute.from_now)
      subject.should be_now
    end
  end

  describe '#past?' do
    it 'is in the past when the end time is in the past' do
      subject.stub(ends_at: 1.second.ago)
      subject.should be_past
    end
  end

  describe '#future?' do
    it 'is in the future when the start time is in the future' do
      subject.stub(starts_at: 1.minute.from_now)
      subject.should be_future
    end
  end

  describe 'duration' do
    it 'calculates duration from start and end times before validation' do
      reservation = create :reservation, starts_at: 1.hour.from_now, ends_at: 3.hours.from_now
      reservation.duration.to_i.should eql(2 * 60 * 60)
    end
  end

  describe '#extend!' do
    it 'allows a user to extend a reservation by 1 hour when the end of the reservation is near' do
      old_reservation_end_time = 40.minutes.from_now
      reservation = create :reservation, starts_at: Time.current, ends_at: old_reservation_end_time, provisioned: true
      expect { reservation.extend! }.to change { reservation.ends_at }
    end

    it 'resets the idle timer when extending' do
      old_reservation_end_time = 40.minutes.from_now
      reservation = create :reservation, starts_at: Time.current, ends_at: old_reservation_end_time, provisioned: true, inactive_minute_counter: 20
      expect { reservation.extend! }.to change { reservation.inactive_minute_counter }.from(20).to(0)
    end

    it 'does not extend a reservation that hasnt been provisioned yet' do
      old_reservation_end_time = 40.minutes.from_now
      reservation = create :reservation, starts_at: Time.current, ends_at: old_reservation_end_time, provisioned: false
      expect { reservation.extend! }.not_to change { reservation.ends_at }
    end

    it "does not extend when there's more than an hour left on the reservation" do
      old_reservation_end_time = 61.minutes.from_now
      reservation = create :reservation, starts_at: Time.current, ends_at: old_reservation_end_time, provisioned: true

      expect { reservation.extend! }.not_to change { reservation.ends_at }
    end
  end

  describe '#cancellable?' do
    it "should be cancellable when the reservation hasn't started yet" do
      subject.stub(future?: true)
      subject.should be_cancellable
    end

    it "should not be cancellable when the reservation is supposed to be active, but isn't provisioned yet" do
      subject.stub(now?: true,
                   future?: false,
                   provisioned?: false)
      subject.should_not be_cancellable
    end

    it "should not be cancellable when it's active and provisioned" do
      subject.stub(now?: true,
                   future?: false,
                   provisioned?: true)
      subject.should_not be_cancellable
    end
  end

  context 'reservation worker' do
    let(:reservation) { create :reservation }

    describe '#start_reservation' do
      it 'should tell the worker to start the reservation' do
        ReservationWorker.should_receive(:perform_async).with(reservation.id, 'start')
        reservation.start_reservation
      end
    end

    describe '#update_reservation' do
      it 'should tell the worker to start the reservation' do
        ReservationWorker.should_receive(:perform_async).with(reservation.id, 'update')
        reservation.update_reservation
      end
    end

    describe '#end_reservation' do
      it 'should tell the worker to end the reservation' do
        ReservationWorker.should_receive(:perform_async).with(reservation.id, 'end')
        reservation.end_reservation
      end
    end
  end

  context 'validations' do
    it 'verifies the server is reservable by the user' do
      users_group                 = create :group,  name: "User's group"
      other_group                 = create :group,  name: "Not User's group"
      user                        = create :user,   groups: [users_group]
      free_server_other_group     = create :server, groups: [other_group], name: "free server not in user's group"

      reservation = build :reservation, server: free_server_other_group
      reservation.should have(1).error_on(:server_id)
      reservation.errors.full_messages.should include 'Server is not available for you'
    end

    it 'allows user to update reservation' do
      user                        = create :user
      reservation                 = create :reservation, user: user

      reservation.password = 'new password'
      reservation.should have(:no).errors_on(:server_id)
    end

    it 'validates the chronologicality of the times' do
      reservation = build :reservation, starts_at: Time.current, ends_at: 29.minutes.from_now
      reservation.should have(1).error_on(:ends_at)
      reservation.errors.full_messages.should include 'Ends at needs to be at least 30 minutes after start time'
      reservation.ends_at = 30.minutes.from_now
      reservation.should have(:no).error_on(:ends_at)
    end

    it 'validates the start time is not too far in the past when creating a new reservation' do
      reservation = build :reservation, starts_at: 16.minutes.ago
      reservation.should have(1).error_on(:starts_at)
      reservation.starts_at = 10.minutes.ago
      reservation.should have(:no).errors_on(:starts_at)
    end

    it 'doesnt validate start time not being in the past when updating a reservation' do
      reservation = create :reservation, starts_at: Time.current
      reservation.starts_at = 16.minutes.ago
      reservation.should have(:no).errors_on(:starts_at)
    end

    it 'validates the end time is at least 30 minutes after start time' do
      reservation = build :reservation, starts_at: Time.current, ends_at: 29.minutes.from_now
      reservation.should have(1).error_on(:ends_at)
      reservation.errors.full_messages.should include 'Ends at needs to be at least 30 minutes after start time'

      reservation.ends_at = 30.minutes.from_now
      reservation.should have(:no).errors_on(:ends_at)
    end

    it 'validates a mvm map was not picked as the first map' do
      reservation = build :reservation
      reservation.first_map = 'mvm_coaltown'
      reservation.should have(1).error_on(:first_map)
      reservation.first_map = 'cp_badlands'
      reservation.should have(:no).errors_on(:first_map)
    end

    it 'validates the server is active' do
      reservation = build :reservation
      reservation.server = create :server, active: false
      reservation.should have(1).errors_on(:server_id)
    end

    it 'allows plugins for non donators' do
      reservation = build :reservation
      reservation.enable_plugins = true
      reservation.should have(:no).errors_on(:enable_plugins)
    end

    context 'for non-donators' do
      it 'has an initial duration of no more than 2 hours' do
        reservation = build :reservation, starts_at: Time.current, ends_at: 121.minutes.from_now
        reservation.should have(1).error_on(:ends_at)
        reservation.errors.full_messages.should include 'Ends at maximum reservation time is 2 hours, you can extend if you run out of time'

        reservation.ends_at = reservation.starts_at + 2.hours
        reservation.should have(:no).errors_on(:ends_at)
      end

      it 'gets extended with 20 minutes at a time' do
        reservation = build :reservation, starts_at: Time.current, ends_at: 31.minutes.from_now
        reservation.user.stub(donator?: false)
        old_ends_at = reservation.ends_at
        reservation.stub(active?: true)

        reservation.extend!

        reservation.ends_at.to_i.should == (old_ends_at + 20.minutes).to_i
      end

      it "doesn't allow multiple future reservations" do
        user = create :user
        user.stub(donator?: false)

        now_reservation           = create :reservation, starts_at: 5.minutes.ago,       ends_at: 1.hour.from_now,    user: user
        first_future_reservation  = create :reservation, starts_at: 90.minutes.from_now, ends_at: 2.hours.from_now,   user: user
        second_future_reservation = build  :reservation, starts_at: 12.hours.from_now,   ends_at: 13.hours.from_now,  user: user

        second_future_reservation.should_not be_valid
        second_future_reservation.should have_at_least(1).error_on(:starts_at)

        now_reservation.starts_at = 12.hours.from_now
        now_reservation.ends_at   = 13.hours.from_now
        now_reservation.should_not be_valid
        now_reservation.should have_at_least(1).error_on(:starts_at)
      end

      it 'does allow editing of a future reservation' do
        user = create :user
        user.stub(donator?: false)

        future_reservation = create :reservation, starts_at: 20.minutes.from_now, ends_at: 1.hour.from_now, user: user

        future_reservation.starts_at = 90.minutes.from_now
        future_reservation.ends_at   = 2.hours.from_now
        future_reservation.should be_valid
      end
    end

    context 'for donators' do
      let(:user) { create(:user) }

      before do
        user.stub(donator?: true)
      end

      it 'has an initial duration of no more than 5 hours' do
        reservation = build :reservation, starts_at: Time.current, ends_at: 301.minutes.from_now, user: user
        reservation.should have(1).error_on(:ends_at)
        reservation.errors.full_messages.should include 'Ends at maximum reservation time is 5 hours, you can extend if you run out of time'

        reservation.ends_at = reservation.starts_at + 5.hours
        reservation.should have(:no).errors_on(:ends_at)
      end

      it 'has an intial duration of no more than 3 hours for gameye servers' do
        server = create(:server, type: 'GameyeServer')
        reservation = build :reservation, starts_at: Time.current, ends_at: 181.minutes.from_now, user: user, server: server, gameye_location: 'frankfurt'
        reservation.should have(1).error_on(:ends_at)
        reservation.errors.full_messages.should include 'Ends at maximum reservation time is 3 hours'

        reservation.ends_at = reservation.starts_at + 3.hours
        reservation.should have(:no).errors_on(:ends_at)
      end

      it 'gets extended with 1 hour at a time' do
        reservation = build :reservation, starts_at: Time.current, ends_at: 31.minutes.from_now, user: user
        reservation.stub(active?: true)
        old_ends_at = reservation.ends_at

        reservation.extend!

        reservation.ends_at.to_i.should == (old_ends_at + 1.hour).to_i
      end

      it 'allows multiple future reservations' do
        user = create :user
        user.stub(donator?: true)
        second_server = create :server
        _first_future_reservation = create :reservation, starts_at: 10.hours.from_now, ends_at: 11.hours.from_now, user: user
        second_future_reservation = build :reservation, starts_at: 12.hours.from_now, ends_at: 13.hours.from_now, user: user, server: second_server

        second_future_reservation.should be_valid
      end
    end

    it "validates you don't collide with another reservation of yourself" do
      user = create(:user)
      create :reservation, user: user, starts_at: Time.current, ends_at: 119.minutes.from_now
      reservation = build :reservation, user: user, starts_at: 90.minutes.from_now, ends_at: 121.minutes.from_now

      reservation.should have_at_least(1).error_on(:starts_at)
      reservation.should have(1).error_on(:ends_at)

      reservation.errors.full_messages.should include 'Starts at you already have a reservation in this timeframe'
      reservation.errors.full_messages.should include 'Ends at you already have a reservation in this timeframe'
    end

    it 'allows extending a reservation past 3 hours' do
      starts = Time.current
      reservation = build :reservation, starts_at: starts, ends_at: (starts + 181.minutes)

      reservation.extending = false
      reservation.should have(1).error_on(:ends_at)

      reservation.extending = true
      reservation.should have(:no).errors_on(:ends_at)
    end
  end

  describe '#server_connect_url' do
    it 'returns a steam connect url for the server' do
      subject.stub(:server).and_return(Server.new(ip: 'fakkelbrigade.eu', port: '27015'))
      subject.stub(:password).and_return('foo')
      subject.server_connect_url.should eql 'steam://connect/fakkelbrigade.eu:27015/foo'
    end
  end

  describe '#stv_connect_url' do
    it 'returns a steam connect url for the STV' do
      subject.stub(:server).and_return(Server.new(ip: 'fakkelbrigade.eu', port: '27015', tv_port: '27025'))
      subject.stub(:tv_password).and_return('bar')
      subject.stv_connect_url.should eql 'steam://connect/fakkelbrigade.eu:27025/bar'
    end
  end

  describe '#connect_string' do
    it 'returns a console connect string' do
      subject.stub(:server).and_return(Server.new(ip: 'fakkelbrigade.eu', port: '27015'))
      subject.stub(:password).and_return('foo')
      subject.connect_string.should eql 'connect fakkelbrigade.eu:27015; password "foo"'
    end
  end

  context 'finding collisions' do
    describe '#collides?' do
      it 'collides if there are any colliding reservations' do
        subject.stub(colliding_reservations: ['foo'])
        expect(subject.collides?).to eql(true)
      end
    end

    describe '#colliding_reservations' do
      it "returns a unique array of collisions with own reservations and other user's reservations" do
        subject.stub(own_colliding_reservations: %w[foo bar])
        subject.stub(other_users_colliding_reservations: %w[foo bar baz])
        subject.colliding_reservations.should eql %w[foo bar baz]
      end
    end

    describe '#own_colliding_reservations' do
      it 'finds colliding reservations from its user' do
        user = create(:user)
        reservation = create(:reservation, user: user, starts_at: Time.current, ends_at: 1.hour.from_now)
        front_overlap = build(:reservation, user: user, starts_at: 10.minutes.ago, ends_at: 50.minutes.from_now)
        internal = build(:reservation, user: user, starts_at: 10.minutes.from_now, ends_at: 50.minutes.from_now)
        rear_overlap = build(:reservation,   user: user, starts_at: 55.minutes.from_now, ends_at: 2.hours.from_now)
        complete_overlap = build(:reservation, user: user, starts_at: 10.minutes.ago, ends_at: 2.hours.from_now)
        identical_times = build(:reservation, user: user, starts_at: reservation.starts_at, ends_at: reservation.ends_at)
        just_before = build(:reservation, user: user, starts_at: reservation.starts_at - 1.hour, ends_at: reservation.starts_at)
        just_after = build(:reservation, user: user, starts_at: reservation.ends_at, ends_at: reservation.ends_at + 1.hour)

        expect(front_overlap.own_colliding_reservations).to match_array([reservation])
        expect(rear_overlap.own_colliding_reservations).to match_array([reservation])
        expect(complete_overlap.own_colliding_reservations).to match_array([reservation])
        expect(internal.own_colliding_reservations).to match_array([reservation])
        expect(identical_times.own_colliding_reservations).to match_array([reservation])
        expect(just_before.own_colliding_reservations).to match_array([])
        expect(just_after.own_colliding_reservations).to match_array([])
      end
    end

    describe '#collides_with_own_reservations?' do
      it 'collides with own reservations if there are any' do
        subject.stub(own_colliding_reservations: ['foo'])
        expect(subject.collides_with_own_reservation?).to eql(true)
      end
    end

    describe '#other_users_colliding_reservations' do
      it 'finds colliding reservations from its server' do
        server = create(:server)
        reservation = create(:reservation, server: server, starts_at: Time.current, ends_at: 1.hour.from_now)
        front_overlap = build(:reservation, server: server, starts_at: 10.minutes.ago, ends_at: 50.minutes.from_now)
        internal = build(:reservation, server: server, starts_at: 10.minutes.from_now, ends_at: 50.minutes.from_now)
        rear_overlap = build(:reservation, server: server, starts_at: 55.minutes.from_now, ends_at: 2.hours.from_now)
        complete_overlap = build(:reservation, server: server, starts_at: 10.minutes.ago, ends_at: 2.hours.from_now)
        identical_times  = build(:reservation, server: server, starts_at: reservation.starts_at, ends_at: reservation.ends_at)
        just_before = build(:reservation, server: server, starts_at: reservation.starts_at - 1.hour, ends_at: reservation.starts_at)
        just_after = build(:reservation, server: server, starts_at: reservation.ends_at, ends_at: reservation.ends_at + 1.hour)

        expect(front_overlap.other_users_colliding_reservations).to match_array([reservation])
        expect(rear_overlap.other_users_colliding_reservations).to match_array([reservation])
        expect(complete_overlap.other_users_colliding_reservations).to match_array([reservation])
        expect(internal.other_users_colliding_reservations).to match_array([reservation])
        expect(identical_times.other_users_colliding_reservations).to match_array([reservation])
        expect(just_before.other_users_colliding_reservations).to match_array([])
        expect(just_after.other_users_colliding_reservations).to match_array([])
      end
    end

    describe '#collides_with_other_users_reservations?' do
      it 'collides with other users reservations if there are any' do
        subject.stub(other_users_colliding_reservations: ['foo'])
        expect(subject.collides_with_other_users_reservation?).to eql(true)
      end
    end

    describe '#inactive_too_long?' do
      context 'for admins' do
        before do
          subject.stub(:user).and_return(mock_model(User, admin?: true, donator?: true))
        end

        it 'has been inactive too long when the inactive_minute_counter reaches 240' do
          subject.inactive_minute_counter = 239
          subject.should_not be_inactive_too_long

          subject.inactive_minute_counter = 240
          subject.should be_inactive_too_long

          subject.inactive_minute_counter = 241
          subject.should be_inactive_too_long
        end
      end

      context 'for donators' do
        before do
          subject.stub(:user).and_return(mock_model(User, donator?: true, admin?: false))
        end

        it 'has been inactive too long when the inactive_minute_counter reaches 240' do
          subject.inactive_minute_counter = 239
          subject.should_not be_inactive_too_long

          subject.inactive_minute_counter = 240
          subject.should be_inactive_too_long

          subject.inactive_minute_counter = 241
          subject.should be_inactive_too_long
        end
      end

      context 'for non-donators' do
        before do
          subject.stub(:user).and_return(mock_model(User, donator?: false, admin?: false))
        end

        it 'has been inactive too long when the inactive_minute_counter reaches 45' do
          subject.inactive_minute_counter = 44
          subject.should_not be_inactive_too_long

          subject.inactive_minute_counter = 45
          subject.should be_inactive_too_long

          subject.inactive_minute_counter = 46
          subject.should be_inactive_too_long
        end
      end
    end
  end

  describe '#just_started?' do
    it 'is just started if it started within the last minute' do
      subject.stub(starts_at: 59.seconds.ago)
      subject.should be_just_started

      subject.stub(starts_at: 61.seconds.ago)
      subject.should_not be_just_started
    end
  end

  describe '#schedulable?' do
    it "is schedulable when it wasn't saved yet" do
      subject.stub(persisted?: false)
      subject.should be_schedulable
    end

    it 'is schedulable when it was saved but not active yet or in the past' do
      subject.stub(persisted?: true,
                   active?: false,
                   past?: false)
      subject.should be_schedulable

      subject.stub(persisted?: true,
                   active?: true,
                   past?: false)
      subject.should_not be_schedulable

      subject.stub(persisted?: true,
                   active?: false,
                   past?: true)
      subject.should_not be_schedulable
    end
  end

  describe '#nearly_over?' do
    it "is nearly over when there's less than 10 minutes left" do
      subject.stub(ends_at: 11.minutes.from_now)
      subject.should_not be_nearly_over

      subject.stub(ends_at: 9.minutes.from_now)
      subject.should be_nearly_over
    end
  end

  describe '#warn_nearly_over' do
    it 'should send a message to the server warning the reservation is nearly over' do
      server = double
      subject.stub(time_left: 1.minute)
      subject.stub(server: server)
      subject.stub(gameye?: false)

      message = 'This reservation will end in less than 1 minute, if this server is not yet booked by someone else, you can say !extend for more time'
      server.should_receive(:rcon_say).with(message)
      server.should_receive(:rcon_disconnect)
      subject.warn_nearly_over
    end
  end

  describe '#reusable_attributes' do
    it 'returns the attributes and values of those attributes that a new reservation can be based on' do
      subject.starts_at = Time.new(2014, 1, 1)
      subject.password = 'the_password'

      subject.reusable_attributes.should include 'password' => 'the_password'
      subject.reusable_attributes.should_not include 'starts_at' => subject.starts_at
    end
  end

  describe '#custom_whitelist_content' do
    it 'should return the text of the custom whitelist do' do
      custom_whitelist_id = 1337
      subject.stub(custom_whitelist_id: 1337)
      whitelist_tf = mock_model(WhitelistTf, content: 'whitelist content')
      WhitelistTf.should_receive(:find_by_tf_whitelist_id).with(custom_whitelist_id).and_return(whitelist_tf)
      subject.custom_whitelist_content.should == 'whitelist content'
    end
  end

  it 'validates format of custom_whitelist_id', :vcr do
    server = create(:server)
    reservation = build(:reservation, server_id: server.id)
    reservation.custom_whitelist_id = 10
    expect(reservation).to be_valid

    reservation.custom_whitelist_id = '~/foobarwidget'
    expect(reservation).to_not be_valid
  end

  describe '#lobby?' do
    it "checks the server's tags for TF2Center" do
      server = double
      tags_line = '"\"sv_tags\" = \"TF2Center,cp,increased_maxplayers,nocrits,nodmgspread\" ( def. \"\" )\n notify\n - Server tags. Used to provide extra information to clients when they\'re browsing for servers. Separate tags with a comma."'
      server.should_receive('rcon_exec').with('sv_tags').and_return(tags_line)
      subject.stub(server: server)

      subject.should be_lobby
    end
  end

  describe '#whitelist_ip' do
    subject { build(:reservation) }
    it "first returns the user's web IP if it's IPv4" do
      create(:reservation_player, steam_uid: subject.user.uid, ip: '10.0.0.1')
      subject.user = build(:user, current_sign_in_ip: '127.0.0.1')
      expect(subject.whitelist_ip).to eql('127.0.0.1')
    end
    it "secondly returns the user's most recent game IP" do
      subject.user = create(:user, current_sign_in_ip: nil)
      create(:reservation_player, steam_uid: subject.user.uid, ip: '10.0.0.1')
      expect(subject.whitelist_ip).to eql('10.0.0.1')
    end
    it "falls back to the site's hosting IP" do
      subject.user = create(:user, current_sign_in_ip: '2a00:23c4:3cfd:c00:000:1b84:6fb8:bf21')
      expect(subject.whitelist_ip).to eql("direct.#{SITE_HOST}")
    end
  end

  it 'validates a gameye reservation do' do
    reservation = build(:reservation)
    reservation.gameye_location = 'frankfurt'
    expect(reservation).to be_valid

    reservation.gameye_location = 'lutjebroek'
    expect(reservation).to_not be_valid
  end
end
