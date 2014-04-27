require 'spec_helper'

describe ReservationsController do

  before do
    @user         = create :user
    @user.groups << Group.admin_group
    sign_in @user
  end

  describe '#show' do

    it "redirects to new_reservation_path when it cant find the reservation" do
      get :show, :id => 'foo'
      response.should redirect_to(new_reservation_path)
    end

    it "shows any reservation for an admin" do
      reservation = create :reservation
      get :show, :id => reservation.id
      assigns(:reservation).should == reservation
    end

  end

  describe "#update" do

    it "redirects to root_path when it tries to update a reservation that is over" do
      reservation = create :reservation, :user => @user
      reservation.update_attribute(:ends_at, 1.hour.ago)

      put :update, :id => reservation.id
      response.should redirect_to(root_path)
    end

  end

  describe "#idle_reset" do

    it "sets the idle timer back to 0" do
      reservation = create :reservation, :user => @user
      reservation.update_attribute(:inactive_minute_counter, 25)

      post :idle_reset, :id => reservation.id
      reservation.reload.inactive_minute_counter.should == 0
    end

  end

  describe "#find_servers_for_reservation" do

    render_views

    it "returns a list of alternative servers for a reservation " do
      reservation = create :reservation, :user => @user
      patch :find_servers_for_reservation, format: :json, id: reservation.id
      response.body.should == {servers: Server.active.map { |s| {id: s.id, name: s.name, flag: s.location.flag} } }.to_json
    end

    it "doesnt return servers in use" do
      create :reservation
      reservation = create :reservation, :user => @user
      patch :find_servers_for_reservation, format: :json, id: reservation.id
      free_server = reservation.server
      response.body.should == {servers: [{id: free_server.id, name: free_server.name, flag: free_server.location.flag}] }.to_json
    end

  end

end
