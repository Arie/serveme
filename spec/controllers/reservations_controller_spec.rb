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
      response.body.should == { servers: [{ id: free_server.id, name: free_server.name, flag: free_server.location.flag, ip: free_server.ip, port: free_server.port, ip_and_port: "#{free_server.ip}:#{free_server.port}", sdr: false, latitude: free_server.latitude, longitude: free_server.longitude }] }.to_json
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

      assigns(:users_games).should == [reservation]
    end
  end

  describe '#streaming' do
    before do
      @user.groups << Group.admin_group
    end

    it 'shows the streaming log file for the reservation' do
      reservation = create :reservation

      expect(File).to receive(:open).with(Rails.root.join('log', 'streaming', "#{reservation.logsecret}.log"))
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
end
