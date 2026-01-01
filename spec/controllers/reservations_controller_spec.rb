# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe ReservationsController do
  before do
    @user = create :user
    @user.groups << Group.admin_group
    allow(@user).to receive(:banned?).and_return(false)
    sign_in @user
  end

  describe '#show' do
    it 'redirects to new_reservation_path when it cant find the reservation' do
      get :show, params: { id: 'foo' }
      response.should redirect_to(new_reservation_path)
    end

    it 'shows any reservation for an admin' do
      reservation = create :reservation
      get :show, params: { id: reservation.id }
      assigns(:reservation).should == reservation
    end
  end

  describe '#new' do
    context 'when an IP is provided' do
      let!(:available_server1) { create :server, ip: '1.2.3.4' }
      let!(:available_server2) { create :server, ip: '1.2.3.4' }
      let!(:unavailable_server) { create :server, ip: '1.2.3.4' }
      let!(:different_ip_server) { create :server, ip: '5.6.7.8' }

      before do
        allow_any_instance_of(ServerForUserFinder).to receive(:servers).and_return(Server.where(id: [ available_server1.id, available_server2.id ]))
      end

      it 'pre-selects a random available server with the matching IP' do
        get :new, params: { ip: '1.2.3.4' }
        expect(assigns(:reservation).server_id).to be_in([ available_server1.id, available_server2.id ])
      end

      it 'does not select a server with a different IP' do
        get :new, params: { ip: '1.2.3.4' }
        expect(assigns(:reservation).server_id).not_to eq(different_ip_server.id)
      end

      it 'does not select an unavailable server' do
        get :new, params: { ip: '1.2.3.4' }
        expect(assigns(:reservation).server_id).not_to eq(unavailable_server.id)
      end
    end

    context 'when no IP is provided' do
      it 'does not pre-select a server' do
        get :new
        expect(assigns(:reservation).server_id).to be_nil
      end
    end

    it 'redirects to root if 2 short reservations were made recently' do
      @user.group_ids = nil
      @user.groups << Group.donator_group
      # Use update_columns to bypass validations for past reservations
      r1 = create :reservation, user: @user, ended: true
      r1.update_columns(starts_at: 9.minutes.ago, ends_at: 8.minutes.ago)
      r2 = create :reservation, user: @user, ended: true
      r2.update_columns(starts_at: 4.minutes.ago, ends_at: 3.minutes.ago)
      get :new
      response.should redirect_to root_path
    end

    it 'makes up an rcon if this is my first reservation' do
      get :new
      assigns(:reservation).rcon.should_not be_nil
    end

    it 'forces a new rcon if my previous rcon was poor' do
      create :reservation, user: @user, rcon: 'foo', starts_at: 10.minutes.ago, ended: true
      get :new
      assigns(:reservation).rcon.should_not == 'foo'
    end
  end

  describe '#update' do
    it 'redirects to root_path when it tries to update a reservation that is over' do
      reservation = create :reservation, user: @user
      reservation.update_attribute(:ends_at, 1.hour.ago)

      put :update, params: { id: reservation.id }
      response.should redirect_to(root_path)
    end
  end

  describe '#find_servers_for_reservation' do
    render_views

    it 'returns a list of alternative servers for a reservation ' do
      reservation = create :reservation, user: @user
      patch :find_servers_for_reservation, format: :json, params: { id: reservation.id }
      response.body.should == { servers: Server.active.map { |s| { id: s.id, name: s.name, flag: s.location.flag, ip: s.ip, port: s.port, ip_and_port: "#{s.ip}:#{s.port}", sdr: false, latitude: s.latitude, longitude: s.longitude } } }.to_json
    end

    it 'doesnt return servers in use' do
      create :reservation
      reservation = create :reservation, user: @user
      patch :find_servers_for_reservation, format: :json, params: { id: reservation.id }
      free_server = reservation.server
      response.body.should == { servers: [ { id: free_server.id, name: free_server.name, flag: free_server.location.flag, ip: free_server.ip, port: free_server.port, ip_and_port: "#{free_server.ip}:#{free_server.port}", sdr: false, latitude: free_server.latitude, longitude: free_server.longitude } ] }.to_json
    end
  end

  describe '#i_am_feeling_lucky' do
    it "shows me my reservation if I'm lucky" do
      reservation = create(:reservation, user: @user)
      lucky = double(:lucky, build_reservation: reservation)
      IAmFeelingLucky.should_receive(:new).and_return(lucky)
      reservation.should_receive(:start_reservation)

      post :i_am_feeling_lucky

      response.should redirect_to reservation_path(reservation)
    end

    it "shows an error if I'm not so lucky" do
      reservation = double(:reservation, human_timerange: 'the_timerange', save: false, valid?: false)
      lucky = double(:lucky, build_reservation: reservation)
      IAmFeelingLucky.should_receive(:new).and_return(lucky)

      post :i_am_feeling_lucky

      response.should redirect_to root_path
    end
  end

  describe '#played_in' do
    it 'shows you a list of reservations you were in, in the last 31 days' do
      played_in = create :reservation_player, user: @user
      reservation = played_in.reservation
      reservation.update_attribute(:ended, true)

      get :played_in

      assigns(:users_games).should == [ reservation ]
    end
  end

  describe '#streaming' do
    before do
      @user.groups << Group.admin_group
    end

    it 'shows the streaming log file for the reservation' do
      reservation = create :reservation

      log_path = Rails.root.join('log', 'streaming', "#{reservation.logsecret}.log")
      allow(File).to receive(:open).and_call_original
      allow(File).to receive(:open).with(log_path).and_return(StringIO.new("Log content"))

      get :streaming, params: { id: reservation.id }
    end
  end

  describe '#status' do
    render_views

    it 'returns the reservation status in json' do
      reservation = create :reservation, starts_at: 10.seconds.from_now
      get :status, params: { id: reservation.id }, format: :json
      expect(response.body).to include 'waiting_to_start'
    end
  end

  describe "#free_servers" do
    render_views

    let(:user) { create(:user, latitude: 52.3676, longitude: 4.9041) }
    let(:london_server) { create(:server, latitude: 51.5074, longitude: -0.1278, position: 1) }
    let(:berlin_server) { create(:server, latitude: 52.5200, longitude: 13.4050, position: 2) }
    let(:non_geocoded_server) { create(:server, latitude: nil, longitude: nil, position: 3) }
    let(:another_non_geocoded) { create(:server, latitude: nil, longitude: nil, position: 4) }

    before do
      sign_in user
      server_ids = [ london_server.id, berlin_server.id, non_geocoded_server.id, another_non_geocoded.id ].shuffle
      allow_any_instance_of(ServerForUserFinder).to receive(:servers).and_return(
        Server.where(id: server_ids)
      )
    end

    context "when user is geocoded" do
      before do
        allow(user).to receive(:geocoded?).and_return(true)
      end

      it "orders servers by geocoded status, distance, position and name" do
        get :find_servers_for_user, format: :json
        servers = JSON.parse(response.body)["servers"]
        ids = servers.map { |s| s["id"] }
        ids.first(2).should == [ london_server.id, berlin_server.id ]
        ids.last(2).should == [ non_geocoded_server.id, another_non_geocoded.id ]
      end
    end

    context "when user is not geocoded" do
      before do
        allow(user).to receive(:geocoded?).and_return(false)
      end

      it "orders servers by position and name" do
        get :find_servers_for_user, format: :json
        servers = JSON.parse(response.body)["servers"]
        ids = servers.map { |s| s["id"] }
        ids.should == [ london_server.id, berlin_server.id, non_geocoded_server.id, another_non_geocoded.id ]
      end
    end
  end

  describe '#index' do
    it 'shows current user reservations by default' do
      reservation = create :reservation, user: @user
      other_reservation = create :reservation

      get :index

      expect(assigns(:users_reservations)).to include(reservation)
      expect(assigns(:users_reservations)).not_to include(other_reservation)
      expect(assigns(:target_user)).to eq(@user)
    end

    context 'when viewing another user reservations' do
      it 'shows specified user reservations when user_id param is present' do
        other_user = create :user
        reservation = create :reservation, user: other_user
        own_reservation = create :reservation, user: @user

        get :index, params: { user_id: other_user.id }

        expect(assigns(:users_reservations)).to include(reservation)
        expect(assigns(:users_reservations)).not_to include(own_reservation)
        expect(assigns(:target_user)).to eq(other_user)
      end
    end
  end

  describe '#motd' do
    it 'loads the reservation and current players with correct password' do
      reservation = create :reservation
      get :motd, params: { id: reservation.id, password: reservation.password }
      expect(assigns(:reservation)).to eq(reservation)
      expect(assigns(:current_players)).to be_an(Array)
      expect(assigns(:distance_unit)).to be_present
      expect(response).to be_successful
    end

    it 'returns unique players only (no duplicates)' do
      reservation = create :reservation
      reservation_player = create :reservation_player, reservation: reservation, steam_uid: '76561198012345678', name: 'TestPlayer'

      # Create multiple player statistics for the same player (simulating frequent updates)
      create :player_statistic, reservation_player: reservation_player, created_at: 1.minute.ago
      create :player_statistic, reservation_player: reservation_player, created_at: 2.minutes.ago
      create :player_statistic, reservation_player: reservation_player, created_at: 3.minutes.ago

      get :motd, params: { id: reservation.id, password: reservation.password }

      current_players = assigns(:current_players)
      player_names = current_players.map { |p| p[:reservation_player]&.name }

      expect(player_names.count('TestPlayer')).to eq(1), "Expected 1 TestPlayer, got #{player_names.count('TestPlayer')}"
    end

    it 'identifies SDR players correctly' do
      reservation = create :reservation

      # Create a regular player with normal IP
      regular_player = create :reservation_player, reservation: reservation, steam_uid: '76561198012345678', name: 'RegularPlayer', ip: '192.168.1.100'
      create :player_statistic, reservation_player: regular_player, created_at: 1.minute.ago

      # Create an SDR player with 169.254.x.x IP
      sdr_player = create :reservation_player, reservation: reservation, steam_uid: '76561198087654321', name: 'SDRPlayer', ip: '169.254.1.100'
      create :player_statistic, reservation_player: sdr_player, created_at: 1.minute.ago

      get :motd, params: { id: reservation.id, password: reservation.password }

      current_players = assigns(:current_players)

      # Find the SDR player in the results
      sdr_player_data = current_players.find { |p| p[:reservation_player]&.name == 'SDRPlayer' }
      regular_player_data = current_players.find { |p| p[:reservation_player]&.name == 'RegularPlayer' }

      expect(sdr_player_data).to be_present
      expect(sdr_player_data[:sdr]).to be_truthy

      expect(regular_player_data).to be_present
      expect(regular_player_data[:sdr]).to be_falsy
    end
  end

  describe '#rcon' do
    render_views

    let(:log_dir) { Rails.root.join('log', 'streaming') }

    before { FileUtils.mkdir_p(log_dir) }

    context 'with a comprehensive log file' do
      let(:reservation) { create(:reservation, user: @user, server: create(:server)) }
      let(:log_file) { log_dir.join("#{reservation.logsecret}.log") }
      let(:log_content) do
        <<~LOG
          L 01/01/2026 - 12:00:00: "Scout<2><[U:1:12345]><Red>" connected, address "192.168.1.1:27005"
          L 01/01/2026 - 12:00:03: World triggered "Round_Start"
          L 01/01/2026 - 12:00:10: "Scout<2><[U:1:12345]><Red>" killed "Medic<3><[U:1:67890]><Blue>" with "scattergun" (attacker_position "1024 512 64") (victim_position "1000 500 60")
          L 01/01/2026 - 12:00:11: "Scout<2><[U:1:12345]><Red>" killed "Sniper<4><[U:1:11111]><Blue>" with "scattergun" (customkill "headshot") (attacker_position "1024 512 64") (victim_position "1000 500 60")
          L 01/01/2026 - 12:00:12: "Spy<5><[U:1:22222]><Blue>" killed "Heavy<6><[U:1:33333]><Red>" with "knife" (customkill "backstab") (attacker_position "500 300 64") (victim_position "500 300 64")
          L 01/01/2026 - 12:00:15: "Soldier<7><[U:1:44444]><Red>" say "nice shot!"
          L 01/01/2026 - 12:00:35: World triggered "Round_Win" (winner "Red")
          L 01/01/2026 - 12:00:40: "Pyro<10><[U:1:77777]><Blue>" committed suicide with "world"
          L 01/01/2026 - 12:00:50: "Scout<2><[U:1:12345]><Red>" disconnected (reason "Disconnect by user.")
        LOG
      end

      before do
        reservation.update_columns(starts_at: 1.hour.ago, ends_at: 1.hour.from_now)
        File.write(log_file, log_content)
      end

      after { FileUtils.rm_f(log_file) }

      it 'renders log lines with proper formatting' do
        get :rcon, params: { id: reservation.id }

        expect(response).to be_successful
        expect(assigns(:log_lines)).to be_present

        # Kill events with weapon icons
        expect(response.body).to include('log-line-kill')
        expect(response.body).to include('killicon')

        # Kill modifiers
        expect(response.body).to include('headshot')
        expect(response.body).to include('backstab')

        # Chat messages
        expect(response.body).to include('log-line-say')
        expect(response.body).to include('nice shot!')

        # Connect/disconnect
        expect(response.body).to include('log-line-connect')
        expect(response.body).to include('log-line-disconnect')

        # Round events
        expect(response.body).to include('log-line-round_start')
        expect(response.body).to include('log-line-round_win')

        # Suicide
        expect(response.body).to include('log-line-suicide')

        # Player team colors
        expect(response.body).to include('team-red')
        expect(response.body).to include('team-blue')

        # Filter controls
        expect(response.body).to include('log-filter-group')
        expect(response.body).to include('log-raw-toggle')
      end

      it 'sanitizes IP addresses in rendered output' do
        get :rcon, params: { id: reservation.id }

        # IP addresses should be sanitized to 0.0.0.0
        expect(response.body).not_to include('192.168.1.1')
        expect(response.body).to include('0.0.0.0')
      end
    end

    context 'with RCON commands containing sensitive data' do
      let(:reservation) { create(:reservation, user: @user, server: create(:server)) }
      let(:log_file) { log_dir.join("#{reservation.logsecret}.log") }
      let(:log_content) do
        <<~LOG
          L 01/01/2026 - 12:00:00: rcon from "46.4.87.20:41762": command "sv_logsecret 75313243783007334810188687151252384638; logstf_apikey "63625991abbfde2aca687ac8c2ac84ad""
          L 01/01/2026 - 12:00:05: rcon from "192.168.1.100:27015": command "rcon_password "supersecret123""
          L 01/01/2026 - 12:00:10: rcon from "10.0.0.1:27015": command "sv_password "matchpassword""
        LOG
      end

      before do
        reservation.update_columns(starts_at: 1.hour.ago, ends_at: 1.hour.from_now)
        File.write(log_file, log_content)
      end

      after { FileUtils.rm_f(log_file) }

      it 'sanitizes IP addresses and secrets in both raw and formatted views' do
        get :rcon, params: { id: reservation.id }

        expect(response).to be_successful

        # IPs should be sanitized
        expect(response.body).not_to include('46.4.87.20')
        expect(response.body).not_to include('192.168.1.100')
        expect(response.body).not_to include('10.0.0.1')

        # Secrets should be sanitized
        expect(response.body).not_to include('75313243783007334810188687151252384638')
        expect(response.body).not_to include('63625991abbfde2aca687ac8c2ac84ad')
        expect(response.body).not_to include('supersecret123')
        expect(response.body).not_to include('matchpassword')

        # Should show masked versions
        expect(response.body).to include('0.0.0.0')
        expect(response.body).to include('*****')
      end
    end

    context 'without a log file' do
      let(:reservation) { create(:reservation, user: @user, server: create(:server)) }

      before { reservation.update_columns(starts_at: 1.hour.ago, ends_at: 1.hour.from_now) }

      it 'handles missing log file gracefully' do
        get :rcon, params: { id: reservation.id }

        expect(response).to be_successful
        expect(assigns(:log_lines)).to eq([])
      end
    end
  end
end
