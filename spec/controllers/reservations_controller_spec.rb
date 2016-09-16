require 'spec_helper'

describe ReservationsController do

  before do
    @user         = create :user
    @user.groups << Group.admin_group
    sign_in @user
  end

  describe '#show' do

    it "redirects to new_reservation_path when it cant find the reservation" do
      get :show, params: { id: 'foo' }
      response.should redirect_to(new_reservation_path)
    end

    it "shows any reservation for an admin" do
      reservation = create :reservation
      get :show, params: { id: reservation.id }
      assigns(:reservation).should == reservation
    end

  end

  describe "#new" do

    it "redirects to root if 2 short reservations were made recently" do
      @user.groups << Group.donator_group
      create :reservation, :user => @user, :starts_at => 9.minutes.ago, :ended => true
      create :reservation, :user => @user, :starts_at => 4.minutes.ago, :ended => true
      get :new
      response.should redirect_to root_path
    end

  end

  describe "#update" do

    it "redirects to root_path when it tries to update a reservation that is over" do
      reservation = create :reservation, :user => @user
      reservation.update_attribute(:ends_at, 1.hour.ago)

      put :update, params: { id: reservation.id }
      response.should redirect_to(root_path)
    end

  end

  describe "#idle_reset" do

    it "sets the idle timer back to 0" do
      reservation = create :reservation, :user => @user
      reservation.update_attribute(:inactive_minute_counter, 25)

      post :idle_reset, params: { id: reservation.id }
      reservation.reload.inactive_minute_counter.should == 0
    end

  end

  describe "#find_servers_for_reservation" do

    render_views

    it "returns a list of alternative servers for a reservation " do
      reservation = create :reservation, :user => @user
      patch :find_servers_for_reservation, format: :json, params: { id: reservation.id }
      response.body.should == {servers: Server.active.map { |s| {id: s.id, name: s.name, flag: s.location.flag, ip_and_port: "#{s.ip}:#{s.port}"} } }.to_json
    end

    it "doesnt return servers in use" do
      create :reservation
      reservation = create :reservation, :user => @user
      patch :find_servers_for_reservation, format: :json, params: { id: reservation.id }
      free_server = reservation.server
      response.body.should == {servers: [{id: free_server.id, name: free_server.name, flag: free_server.location.flag, ip_and_port: "#{free_server.ip}:#{free_server.port}"}] }.to_json
    end

  end

  describe "#i_am_feeling_lucky" do

    render_views

    it "shows me my reservation if I'm lucky" do
      reservation = create(:reservation, :user => @user)
      lucky = double(:lucky, :build_reservation => reservation)
      IAmFeelingLucky.should_receive(:new).and_return(lucky)

      post :i_am_feeling_lucky

      response.should redirect_to reservation_path(reservation)
    end

    it "shows an error if I'm not so lucky" do
      reservation = double(:reservation, :human_timerange => "the_timerange", :save => false, :valid? => false)
      lucky = double(:lucky, :build_reservation => reservation)
      IAmFeelingLucky.should_receive(:new).and_return(lucky)

      post :i_am_feeling_lucky

      response.should redirect_to root_path
    end

  end

  describe "#played_in" do

    it "shows you a list of reservations you were in, in the last 31 days" do
      played_in = create :reservation_player, user: @user
      reservation = played_in.reservation
      reservation.update_attribute(:ended, true)

      get :played_in

      assigns(:users_games).should == [reservation]
    end

  end

end
