# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe ReservationsController do
  before do
    @user = create :user
    @user.groups << Group.admin_group
    @user.stub(banned?: false)
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
      create :reservation, user: @user, starts_at: 9.minutes.ago, ended: true
      create :reservation, user: @user, starts_at: 4.minutes.ago, ended: true
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
    render_views

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
  end
end
