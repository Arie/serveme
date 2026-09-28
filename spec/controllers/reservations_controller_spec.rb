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
      let(:available_server1) { create :server, ip: '1.2.3.4' }
      let(:available_server2) { create :server, ip: '1.2.3.4' }
      let(:unavailable_server) { create :server, ip: '1.2.3.4' }
      let(:different_ip_server) { create :server, ip: '5.6.7.8' }

      let(:server_finder) { instance_double(ServerForUserFinder) }

      before do
        allow(ServerForUserFinder).to receive(:new).and_return(server_finder)
        allow(server_finder).to receive(:servers).and_return(Server.where(id: [ available_server1.id, available_server2.id ]))
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

    context 'with site wide feature flags' do
      render_views

      it 'offers the choice when the flags are off' do
        allow(SiteSetting).to receive(:always_enable_demos_tf?).and_return(false)

        get :new

        expect(response.body).to have_css('input[type="checkbox"][name="reservation[enable_demos_tf]"]:not([disabled])', visible: :all)
      end

      it 'shows demos.tf as on and unchangeable when the site always enables it' do
        allow(SiteSetting).to receive(:always_enable_demos_tf?).and_return(true)

        get :new

        expect(response.body).to have_css('input[type="checkbox"][name="reservation[enable_demos_tf]"][checked][disabled]', visible: :all)
      end

      it 'shows plugins as on and unchangeable when the site always enables them' do
        allow(SiteSetting).to receive(:always_enable_plugins?).and_return(true)

        get :new

        expect(response.body).to have_css('input[type="checkbox"][name="reservation[enable_plugins]"][checked][disabled]', visible: :all)
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

  describe '#create with docker host' do
    let(:docker_host) { create(:docker_host) }

    let(:docker_params) do
      {
        reservation: {
          server_id: "dh-#{docker_host.id}",
          password: "testpass",
          rcon: "testrcon",
          enable_plugins: "1",
          auto_end: "1",
          starts_at: Time.current.to_s,
          ends_at: 2.hours.from_now.to_s
        }
      }
    end

    it "creates a cloud server reservation for a docker host" do
      expect(CloudServerProvisionWorker).to receive(:perform_async)

      post :create, params: docker_params

      reservation = Reservation.last
      expect(reservation.server).to be_a(CloudServer)
      expect(reservation.server.cloud_provider).to eq("remote_docker")
      expect(response).to redirect_to(reservation_path(reservation))
      expect(flash[:notice]).to include("provisioned")
    end

    it "redirects with error when docker host is full" do
      allow_any_instance_of(DockerHost).to receive(:full_during?).and_return(true)

      post :create, params: docker_params

      expect(response).to redirect_to(new_reservation_path)
      expect(flash[:alert]).to include("full capacity")
    end
  end

  describe '#create' do
    it 'renders the new form with an error when an unparseable date is given' do
      post :create, params: { reservation: { starts_at: 'garbage', ends_at: 'garbage', password: 'x', rcon: 'y' } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(flash[:alert]).to include('Invalid date or time')
    end

    it 'does not double-book a server when a competitor commits while waiting for the per-server lock' do
      server = create(:server)
      other_user = create(:user)
      starts_at = Time.current
      ends_at = 2.hours.from_now

      # Simulate a competitor grabbing the same server in the window between our
      # first validation and acquiring the per-server lock.
      allow($lock).to receive(:synchronize) do |_key, &block|
        create(:reservation, user: other_user, server: server, starts_at: starts_at, ends_at: ends_at)
        block.call
      end

      post :create, params: { reservation: {
        server_id: server.id, password: 'x', rcon: 'y',
        starts_at: starts_at.to_s, ends_at: ends_at.to_s
      } }

      expect(Reservation.where(server_id: server.id).count).to eq(1)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'does not double-book a server when the competitor commits on another connection' do
      server = create(:server)
      other_user = create(:user)
      starts_at = Time.current
      ends_at = 2.hours.from_now

      allow($lock).to receive(:synchronize) do |_key, &block|
        ActiveRecord::Base.uncached(dirties: false) do
          create(:reservation, user: other_user, server: server, starts_at: starts_at, ends_at: ends_at)
        end
        block.call
      end

      ActiveRecord::Base.cache do
        post :create, params: { reservation: {
          server_id: server.id, password: 'x', rcon: 'y',
          starts_at: starts_at.to_s, ends_at: ends_at.to_s
        } }
      end

      expect(Reservation.where(server_id: server.id).count).to eq(1)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'shows an error instead of crashing when the competitor commits after the last validation' do
      server = create(:server)
      other_user = create(:user)
      starts_at = Time.current.change(sec: 0)
      ends_at = 2.hours.from_now.change(sec: 0)

      competitor_created = false
      allow_any_instance_of(Reservation).to receive(:generate_logsecret).and_wrap_original do |original, *args|
        unless competitor_created
          competitor_created = true
          create(:reservation, user: other_user, server: server, starts_at: starts_at, ends_at: ends_at)
        end
        original.call(*args)
      end

      post :create, params: { reservation: {
        server_id: server.id, password: 'x', rcon: 'y',
        starts_at: starts_at.to_s, ends_at: ends_at.to_s
      } }

      expect(Reservation.where(user_id: @user.id, server_id: server.id)).to be_empty
      expect(response).to have_http_status(:unprocessable_entity)
      expect(assigns(:reservation).errors[:server_id]).to include('already booked in the selected timeframe')
    end

    it 'shows an error when the competitor books an overlapping, not identical, timeframe' do
      server = create(:server)
      other_user = create(:user)
      starts_at = Time.current.change(sec: 0)
      ends_at = 2.hours.from_now.change(sec: 0)

      competitor_created = false
      allow_any_instance_of(Reservation).to receive(:generate_logsecret).and_wrap_original do |original, *args|
        unless competitor_created
          competitor_created = true
          create(:reservation, user: other_user, server: server,
                               starts_at: starts_at + 1.minute, ends_at: ends_at + 1.minute)
        end
        original.call(*args)
      end

      post :create, params: { reservation: {
        server_id: server.id, password: 'x', rcon: 'y',
        starts_at: starts_at.to_s, ends_at: ends_at.to_s
      } }

      expect(Reservation.where(user_id: @user.id, server_id: server.id)).to be_empty
      expect(response).to have_http_status(:unprocessable_entity)
      expect(assigns(:reservation).errors[:server_id]).to include('already booked in the selected timeframe')
    end
  end

  describe '#find_servers_for_reservation' do
    render_views

    it 'returns a list of alternative servers for a reservation ' do
      reservation = create :reservation, user: @user
      patch :find_servers_for_reservation, format: :json, params: { id: reservation.id }
      response.body.should == { servers: Server.active.map { |s| { id: s.id, name: s.name, flag: s.location.flag, ip: s.ip, port: s.port, ip_and_port: "#{s.ip}:#{s.port}", resolved_ip: s.resolved_ip, sdr: false, latitude: s.latitude, longitude: s.longitude } } }.to_json
    end

    it 'doesnt return servers in use' do
      create :reservation
      reservation = create :reservation, user: @user
      patch :find_servers_for_reservation, format: :json, params: { id: reservation.id }
      free_server = reservation.server
      response.body.should == { servers: [ { id: free_server.id, name: free_server.name, flag: free_server.location.flag, ip: free_server.ip, port: free_server.port, ip_and_port: "#{free_server.ip}:#{free_server.port}", resolved_ip: free_server.resolved_ip, sdr: false, latitude: free_server.latitude, longitude: free_server.longitude } ] }.to_json
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

    it 'does not double-book a server when a competitor commits while waiting for the per-server lock' do
      server = create(:server)
      other_user = create(:user)
      reservation = Reservation.new(user: @user, server: server, password: 'x', rcon: 'y',
                                    starts_at: Time.current, ends_at: 2.hours.from_now)
      lucky = double(:lucky, build_reservation: reservation)
      IAmFeelingLucky.should_receive(:new).and_return(lucky)

      # Simulate a competitor grabbing the same server in the window between our
      # first validation and acquiring the per-server lock.
      allow($lock).to receive(:synchronize) do |_key, &block|
        create(:reservation, user: other_user, server: server, starts_at: reservation.starts_at, ends_at: reservation.ends_at)
        block.call
      end

      post :i_am_feeling_lucky

      expect(Reservation.where(server_id: server.id, user_id: @user.id)).to be_empty
      expect(response).to redirect_to root_path
      expect(flash[:alert]).to include('not very lucky')
    end

    it 'shows the unlucky message instead of crashing when the competitor commits after the last validation' do
      server = create(:server)
      other_user = create(:user)
      starts_at = Time.current.change(sec: 0)
      ends_at = 2.hours.from_now.change(sec: 0)
      reservation = Reservation.new(user: @user, server: server, password: 'x', rcon: 'y',
                                    starts_at: starts_at, ends_at: ends_at)
      lucky = double(:lucky, build_reservation: reservation)
      IAmFeelingLucky.should_receive(:new).and_return(lucky)

      competitor_created = false
      allow_any_instance_of(Reservation).to receive(:generate_logsecret).and_wrap_original do |original, *args|
        unless competitor_created
          competitor_created = true
          create(:reservation, user: other_user, server: server, starts_at: starts_at, ends_at: ends_at)
        end
        original.call(*args)
      end

      post :i_am_feeling_lucky

      expect(Reservation.where(server_id: server.id, user_id: @user.id)).to be_empty
      expect(response).to redirect_to root_path
      expect(flash[:alert]).to include('not very lucky')
    end

    it "shows an error if I'm not so lucky" do
      reservation = double(:reservation, human_timerange: 'the_timerange', server: nil, save: false, valid?: false)
      lucky = double(:lucky, build_reservation: reservation, available_docker_host: nil)
      IAmFeelingLucky.should_receive(:new).and_return(lucky)

      post :i_am_feeling_lucky

      response.should redirect_to root_path
    end

    it "books a remote-docker host when no regular server is free" do
      docker_host = create(:docker_host)
      created = create(:reservation, user: @user)
      reservation = double(:reservation, server: nil, valid?: false)
      lucky = double(:lucky,
        build_reservation: reservation,
        available_docker_host: docker_host,
        docker_host_reservation_params: { password: 'secret' }.with_indifferent_access)
      IAmFeelingLucky.should_receive(:new).and_return(lucky)
      creator = double(:creator, create!: created)
      DockerHostReservationCreator.should_receive(:new)
        .with(hash_including(user: @user, docker_host_id: docker_host.id))
        .and_return(creator)

      post :i_am_feeling_lucky

      response.should redirect_to reservation_path(created)
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

    let(:server_finder) { instance_double(ServerForUserFinder) }

    before do
      sign_in user
      server_ids = [ london_server.id, berlin_server.id, non_geocoded_server.id, another_non_geocoded.id ].shuffle
      allow(ServerForUserFinder).to receive(:new).and_return(server_finder)
      allow(server_finder).to receive(:servers).and_return(
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
    let(:log_dir) { Rails.root.join('log', 'streaming') }

    before { FileUtils.mkdir_p(log_dir) }

    context 'with a log file' do
      let(:reservation) { create(:reservation, user: @user, server: create(:server)) }
      let(:log_file) { log_dir.join("#{reservation.logsecret}.log") }

      before do
        reservation.update_columns(starts_at: 1.hour.ago, ends_at: 1.hour.from_now)
        File.write(log_file, "line1\nline2\nline3\n")
      end

      after { FileUtils.rm_f(log_file) }

      it 'returns the page shell with total line count' do
        get :rcon, params: { id: reservation.id }

        expect(response).to be_successful
        expect(assigns(:total_lines)).to eq(3)
      end
    end

    context 'without a log file' do
      let(:reservation) { create(:reservation, user: @user, server: create(:server)) }

      before { reservation.update_columns(starts_at: 1.hour.ago, ends_at: 1.hour.from_now) }

      it 'handles missing log file gracefully' do
        get :rcon, params: { id: reservation.id }

        expect(response).to be_successful
        expect(assigns(:total_lines)).to eq(0)
      end
    end
  end

  describe '#rcon_view' do
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
        get :rcon_view, params: { id: reservation.id, percent: 0, count: 200 }

        expect(response).to be_successful
        json = JSON.parse(response.body)
        html = json['html']

        # Kill events with weapon icons
        expect(html).to include('log-line-kill')
        expect(html).to include('killicon')

        # Kill modifiers
        expect(html).to include('headshot')
        expect(html).to include('backstab')

        # Chat messages
        expect(html).to include('log-line-say')
        expect(html).to include('nice shot!')

        # Connect/disconnect
        expect(html).to include('log-line-connect')
        expect(html).to include('log-line-disconnect')

        # Round events
        expect(html).to include('log-line-round_start')
        expect(html).to include('log-line-round_win')

        # Suicide
        expect(html).to include('log-line-suicide')

        # Player team colors
        expect(html).to include('team-red')
        expect(html).to include('team-blue')
      end

      it 'sanitizes IP addresses for non-admin users' do
        @user.groups.delete(Group.admin_group)
        get :rcon_view, params: { id: reservation.id, percent: 0, count: 200 }

        json = JSON.parse(response.body)
        html = json['html']

        # IP addresses should be sanitized to 0.0.0.0
        expect(html).not_to include('192.168.1.1')
        expect(html).to include('0.0.0.0')
      end

      it 'shows real IP addresses for admin users' do
        get :rcon_view, params: { id: reservation.id, percent: 0, count: 200 }

        json = JSON.parse(response.body)
        html = json['html']

        expect(html).to include('192.168.1.1')
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

      it 'sanitizes secrets for non-admin users' do
        @user.groups.delete(Group.admin_group)
        get :rcon_view, params: { id: reservation.id, percent: 0, count: 200 }

        expect(response).to be_successful
        json = JSON.parse(response.body)
        html = json['html']

        # IPs should be sanitized
        expect(html).not_to include('46.4.87.20')
        expect(html).not_to include('192.168.1.100')

        # Secrets should be sanitized
        expect(html).not_to include('75313243783007334810188687151252384638')
        expect(html).not_to include('supersecret123')

        # Should show masked versions
        expect(html).to include('0.0.0.0')
        expect(html).to include('*****')
      end

      it 'shows secrets for admin users' do
        get :rcon_view, params: { id: reservation.id, percent: 0, count: 200 }

        expect(response).to be_successful
        json = JSON.parse(response.body)
        html = json['html']

        expect(html).to include('46.4.87.20')
        expect(html).to include('supersecret123')
      end
    end

    context 'without a log file' do
      let(:reservation) { create(:reservation, user: @user, server: create(:server)) }

      before { reservation.update_columns(starts_at: 1.hour.ago, ends_at: 1.hour.from_now) }

      it 'returns empty result for missing log file' do
        get :rcon_view, params: { id: reservation.id, percent: 0, count: 200 }

        expect(response).to be_successful
        json = JSON.parse(response.body)
        expect(json['total']).to eq(0)
        expect(json['html'].strip).to eq('')
      end
    end
  end

  describe '#create when the free server limit is reached' do
    it 'redirects back to the new reservation page with an alert' do
      allow(SiteSetting).to receive(:free_server_limit_reached?).and_return(true)
      server = create(:server)

      expect do
        post :create, params: { reservation: { server_id: server.id, password: 'x', rcon: 'y',
                                                starts_at: Time.current.to_s, ends_at: 2.hours.from_now.to_s } }
      end.not_to change(Reservation, :count)

      expect(response).to redirect_to(new_reservation_path)
      expect(flash[:alert]).to include('All free servers are currently in use')
    end
  end

  describe '#create a regular reservation' do
    let(:server) { create(:server) }

    it 'saves a future reservation and redirects to it without starting it' do
      expect_any_instance_of(Reservation).not_to receive(:start_reservation)

      post :create, params: { reservation: { server_id: server.id, password: 'x', rcon: 'y',
                                              starts_at: 1.hour.from_now.to_s, ends_at: 3.hours.from_now.to_s } }

      reservation = Reservation.find_by(user_id: @user.id, server_id: server.id)
      expect(reservation).to be_present
      expect(reservation.start_instantly).to be(false)
      expect(response).to redirect_to(reservation_path(reservation))
      expect(flash[:notice]).to be_nil
    end

    it 'starts a reservation that begins now' do
      expect_any_instance_of(Reservation).to receive(:start_reservation)

      post :create, params: { reservation: { server_id: server.id, password: 'x', rcon: 'y',
                                              starts_at: Time.current.to_s, ends_at: 2.hours.from_now.to_s } }

      reservation = Reservation.find_by(user_id: @user.id, server_id: server.id)
      expect(reservation.start_instantly).to be(true)
      expect(response).to redirect_to(reservation_path(reservation))
      expect(flash[:notice]).to include('Reservation created for')
    end
  end

  describe '#create with docker host validation errors' do
    it 're-renders the form with the invalid reservation' do
      docker_host = create(:docker_host)
      invalid = Reservation.new(password: 'x')
      creator = instance_double(DockerHostReservationCreator)
      allow(creator).to receive(:create!).and_raise(DockerHostReservationCreator::ValidationError.new('invalid', invalid))
      expect(DockerHostReservationCreator).to receive(:new)
        .with(hash_including(user: @user, docker_host_id: docker_host.id))
        .and_return(creator)

      post :create, params: { reservation: { server_id: "dh-#{docker_host.id}", password: 'x', rcon: 'y',
                                              starts_at: Time.current.to_s, ends_at: 2.hours.from_now.to_s } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response).to render_template(:new)
      expect(assigns(:reservation)).to be(invalid)
      expect(assigns(:docker_hosts)).to include(docker_host)
    end
  end

  describe '#i_am_feeling_lucky extra paths' do
    it 'redirects to root when the free server limit is reached' do
      allow(SiteSetting).to receive(:free_server_limit_reached?).and_return(true)
      expect(IAmFeelingLucky).not_to receive(:new)

      post :i_am_feeling_lucky

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to include('All free servers are currently in use')
    end

    it 'shows the unlucky message when the docker host is full' do
      docker_host = create(:docker_host)
      reservation = double(:reservation, server: nil, valid?: false)
      lucky = double(:lucky,
        build_reservation: reservation,
        available_docker_host: docker_host,
        docker_host_reservation_params: { password: 'secret' }.with_indifferent_access)
      allow(IAmFeelingLucky).to receive(:new).and_return(lucky)
      creator = instance_double(DockerHostReservationCreator)
      allow(creator).to receive(:create!).and_raise(DockerHostReservationCreator::CapacityError, 'full')
      allow(DockerHostReservationCreator).to receive(:new).and_return(creator)

      post :i_am_feeling_lucky

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("You're not very lucky, no server is available right now :(")
    end
  end

  describe '#edit' do
    it 'loads the reservation and the selectable servers' do
      reservation = create :reservation, user: @user

      get :edit, params: { id: reservation.id }

      expect(response).to be_successful
      expect(assigns(:reservation)).to eq(reservation)
      expect(assigns(:servers)).to include(reservation.server)
    end
  end

  describe '#update of a current or future reservation' do
    it 'updates a future reservation and redirects to root' do
      reservation = create :reservation, user: @user, starts_at: 1.hour.from_now, ends_at: 2.hours.from_now

      put :update, params: { id: reservation.id, reservation: { password: 'newpass' } }

      expect(reservation.reload.password).to eq('newpass')
      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq("Reservation updated for #{reservation}")
    end

    it 'pushes the changes to the server for a reservation that is running' do
      reservation = create :reservation, user: @user
      expect_any_instance_of(Reservation).to receive(:update_reservation)

      put :update, params: { id: reservation.id, reservation: { password: 'newpass' } }

      expect(reservation.reload.password).to eq('newpass')
      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to include('your changes will be active after a mapchange')
    end
  end

  describe '#extend_reservation' do
    let(:reservation) { create :reservation, user: @user }

    it 'shows the new end time when extending succeeds' do
      expect_any_instance_of(Reservation).to receive(:extend!).and_return(true)

      post :extend_reservation, params: { id: reservation.id }

      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq("Reservation extended to #{I18n.l(reservation.ends_at, format: :datepicker)}")
    end

    it 'shows an alert when extending fails' do
      expect_any_instance_of(Reservation).to receive(:extend!).and_return(false)

      post :extend_reservation, params: { id: reservation.id }

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('Could not extend, conflicting reservation')
    end
  end

  describe '#destroy' do
    it 'cancels a future reservation' do
      reservation = create :reservation, user: @user, starts_at: 1.hour.from_now, ends_at: 2.hours.from_now

      delete :destroy, params: { id: reservation.id }

      expect(Reservation.exists?(reservation.id)).to be(false)
      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to include('cancelled')
    end

    it 'refuses to end a reservation that was provisioned in the last minute' do
      reservation = create :reservation, user: @user
      reservation.update_columns(starts_at: 30.seconds.ago, provisioned: true)
      expect_any_instance_of(Reservation).not_to receive(:end_reservation)

      delete :destroy, params: { id: reservation.id }

      expect(Reservation.exists?(reservation.id)).to be(true)
      expect(response).to redirect_to(reservation_path(reservation))
      expect(flash[:alert]).to include('started in the last 2 minutes')
    end

    it 'ends a running reservation' do
      reservation = create :reservation, user: @user
      reservation.update_columns(starts_at: 10.minutes.ago, provisioned: true)
      expect_any_instance_of(Reservation).to receive(:end_reservation)

      delete :destroy, params: { id: reservation.id }

      expect(reservation.reload.end_instantly).to be(true)
      expect(response).to redirect_to(reservation_path(reservation))
      expect(flash[:notice]).to include('Reservation removed')
    end
  end

  describe 'log views with a log file' do
    let(:log_dir) { Rails.root.join('log', 'streaming') }
    let(:reservation) { create(:reservation, user: @user) }
    let(:log_file) { log_dir.join("#{reservation.logsecret}.log") }

    before do
      FileUtils.mkdir_p(log_dir)
      File.write(log_file, (1..30).map { |i| "L 01/01/2026 - 12:00:#{format('%02d', i)}: \"Player<2><[U:1:1]><Red>\" say \"msg #{i}\"" }.join("\n") + "\n")
    end

    after { FileUtils.rm_f(log_file) }

    it 'streaming counts the lines of the log' do
      get :streaming, params: { id: reservation.id, q: ' say ' }

      expect(response).to be_successful
      expect(assigns(:total_lines)).to eq(30)
      expect(assigns(:initial_query)).to eq('say')
    end

    context 'with rendered views' do
      render_views

      it 'streaming_view returns the lines around a requested line number' do
        get :streaming_view, params: { id: reservation.id, line: 20, count: 10 }

        json = JSON.parse(response.body)
        expect(json['total']).to eq(30)
        expect(json['start_index']).to be <= 19
        expect(json['end_index']).to be >= 19
        expect(json['html']).to include('msg 20')
        expect(json['is_search']).to be(false)
      end
    end
  end

  describe '#rcon_command' do
    render_views

    let(:reservation) { create(:reservation, user: @user) }

    it 'executes the command on the server and renders the response as a turbo stream' do
      expect_any_instance_of(Server).to receive(:rcon_exec).with('changelevel cp_badlands', allow_blocked: true).and_return('Changing level')

      patch :rcon_command, params: { id: reservation.id, query: 'rcon map cp_badlands' }, format: :turbo_stream

      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(response.body).to include('rcon_response')
      expect(response.body).to include('changelevel cp_badlands')
      expect(response.body).to include('Changing level')
    end

    it 'does not allow blocked commands for a regular user and redirects for html' do
      @user.groups.delete(Group.admin_group)
      expect_any_instance_of(Server).to receive(:rcon_exec).with('status', allow_blocked: false).and_return('ok')

      patch :rcon_command, params: { id: reservation.id, reservation: { rcon_command: 'status' } }

      expect(response).to redirect_to(rcon_reservation_path(reservation))
    end

    it 'extends the reservation with !extend' do
      expect_any_instance_of(Reservation).to receive(:extend!).and_return(true)
      expect_any_instance_of(Server).not_to receive(:rcon_exec)

      patch :rcon_command, params: { id: reservation.id, query: '!extend' }, format: :turbo_stream

      expect(response.body).to include('Reservation extended to')
    end

    it 'reports a failed extend' do
      expect_any_instance_of(Reservation).to receive(:extend!).and_return(false)

      patch :rcon_command, params: { id: reservation.id, query: 'extend' }, format: :turbo_stream

      expect(response.body).to include('Could not extend, conflicting reservation')
    end

    it 'ends the reservation with !end' do
      expect_any_instance_of(Reservation).to receive(:end_reservation)

      patch :rcon_command, params: { id: reservation.id, query: '!end' }, format: :turbo_stream

      expect(response.body).to include('Ending reservation')
      expect(reservation.reload.end_instantly).to be(true)
    end

    it 'renders not found when the reservation is not running' do
      reservation.update_columns(starts_at: 1.hour.from_now, ends_at: 2.hours.from_now)
      expect_any_instance_of(Server).not_to receive(:rcon_exec)

      patch :rcon_command, params: { id: reservation.id, query: 'status' }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe '#motd_rcon_command' do
    it 'redirects back to the motd page for html requests' do
      reservation = create(:reservation, user: @user)
      expect_any_instance_of(Server).to receive(:rcon_exec).with('status', allow_blocked: true).and_return('ok')

      patch :motd_rcon_command, params: { id: reservation.id, query: 'status' }

      expect(response).to redirect_to(motd_reservation_path(reservation))
    end
  end

  describe '#rcon_autocomplete' do
    it 'assigns suggestions from RconAutocomplete' do
      reservation = create(:reservation, user: @user)
      autocomplete = instance_double(RconAutocomplete)
      expect(RconAutocomplete).to receive(:new).with(reservation).and_return(autocomplete)
      expect(autocomplete).to receive(:autocomplete).with('mp_').and_return([ { command: 'mp_restartgame' } ])

      get :rcon_autocomplete, params: { id: reservation.id, query: 'mp_', reservation_id: reservation.id.to_s }

      expect(response).to be_successful
      expect(assigns(:suggestions)).to eq([ { command: 'mp_restartgame' } ])
      expect(assigns(:query)).to eq('mp_')
      expect(assigns(:reservation_id)).to eq(reservation.id)
    end
  end

  describe '#stac_log' do
    let(:reservation) { create(:reservation) }

    it 'sends the joined stac logs as plain text' do
      create(:stac_log, reservation: reservation, contents: 'first log')
      create(:stac_log, reservation: reservation, contents: 'second log')

      get :stac_log, params: { id: reservation.id }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/plain')
      expect(response.body.split("\n")).to contain_exactly('first log', 'second log')
      expect(response.headers['Content-Disposition']).to include("stac_logs_#{reservation.id}.log")
    end

    it 'returns not found when there are no stac logs' do
      get :stac_log, params: { id: reservation.id }

      expect(response).to have_http_status(:not_found)
      expect(response.body).to eq('No STAC logs found')
    end

    it 'returns not found for an invalid id' do
      get :stac_log, params: { id: 'foo' }

      expect(response).to have_http_status(:not_found)
    end

    context 'as a regular user' do
      before { @user.groups.delete(Group.admin_group) }

      it 'denies access to reservations the user did not make or play in' do
        create(:stac_log, reservation: reservation)

        get :stac_log, params: { id: reservation.id }

        expect(response).to have_http_status(:not_found)
        expect(response.body).to be_empty
      end

      it 'allows access to reservations the user played in' do
        reservation.update_columns(ended: true)
        create(:reservation_player, reservation: reservation, user: @user, steam_uid: @user.uid)
        create(:stac_log, reservation: reservation, contents: 'played log')

        get :stac_log, params: { id: reservation.id }

        expect(response).to have_http_status(:ok)
        expect(response.body).to eq('played log')
      end

      it 'allows access to reservations the user made' do
        own = create(:reservation, user: @user)
        create(:stac_log, reservation: own, contents: 'own log')

        get :stac_log, params: { id: own.id }

        expect(response.body).to eq('own log')
      end
    end
  end

  describe '#prepare_zip' do
    let(:reservation) { create(:reservation, user: @user) }

    it 'returns not found for an unknown reservation' do
      post :prepare_zip, params: { id: 0 }, format: :turbo_stream

      expect(response).to have_http_status(:not_found)
    end

    it 'renders a direct link when the zip exists locally' do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(reservation.local_zipfile_path).and_return(true)
      expect(DownloadZipWorker).not_to receive(:perform_in)

      post :prepare_zip, params: { id: reservation.id }, format: :turbo_stream

      expect(response).to be_successful
      expect(response.body).to include('turbo-stream action="replace"')
      expect(response.body).to include("zip_download_status_reservation_#{reservation.id}")
    end

    it 'enqueues a download and renders progress when the zip is only in storage' do
      allow_any_instance_of(Reservation).to receive(:zipfile).and_return(double(attached?: true))
      expect(DownloadZipWorker).to receive(:perform_in).with(1.second, reservation.id)

      post :prepare_zip, params: { id: reservation.id }, format: :turbo_stream

      expect(response).to be_successful
      expect(response.body).to include("zip_prepare_button_form_reservation_#{reservation.id}")
      expect(response.body).to include('turbo-cable-stream-source')
    end

    it 'returns unprocessable entity when no zip is available' do
      expect(DownloadZipWorker).not_to receive(:perform_in)

      post :prepare_zip, params: { id: reservation.id }, format: :turbo_stream

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
