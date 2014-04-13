require 'spec_helper'

describe Api::ReservationsController do

  render_views

  before do
    @user = create :user
    controller.stub(:current_user => @user)
  end

  describe "#new" do

    it 'renders a json to be filled in' do
      get :new, format: :json
      json = {
        reservation: {
          starts_at: String,
          ends_at: String
        }.ignore_extra_keys!
      }.ignore_extra_keys!
      expect(response.body).to match_json_expression(json)
    end

  end

  describe "#find_servers" do

    it "returns a reservation json to be filled in with available servers" do
      post :find_servers, reservation: { starts_at: Time.current.to_s, ends_at: (Time.current + 2.hours).to_s }, format: :json
      json = {
        reservation: {
          starts_at: String,
          ends_at: String,
          rcon: wildcard_matcher,
          password: wildcard_matcher,
          tv_password: wildcard_matcher,
          tv_relaypassword: wildcard_matcher,
        }.ignore_extra_keys!,
        servers: Array,
        whitelists: Array,
        server_configs: Array,
        actions: Hash
        }
      expect(response.body).to match_json_expression(json)
    end
  end

  describe "#show" do

    it "returns a json of a reservation" do
      reservation = create :reservation, :user => @user
      get :show, :id => reservation.id, format: :json
      json = {
        reservation: {
          starts_at: String,
          ends_at: String,
          rcon: reservation.rcon,
          password: reservation.password,
          tv_password: reservation.tv_password,
          tv_relaypassword: reservation.tv_relaypassword
        }.ignore_extra_keys!
      }.ignore_extra_keys!
      expect(response.body).to match_json_expression(json)
    end

    it "returns a 404 for an unknown reservation" do

      get :show, :id => -1
      response.status.should == 404
    end

  end

  describe "#create" do

    it "saves a valid reservation and shows the results" do
      server = create :server, :location => create(:location)
      json = {
        reservation: {
          starts_at: String,
          ends_at: String,
          server_id: server.id,
          rcon: wildcard_matcher,
          password: wildcard_matcher,
          tv_password: wildcard_matcher,
          tv_relaypassword: wildcard_matcher,
          logsecret: wildcard_matcher,
          last_number_of_players: Fixnum,
          inactive_minute_counter: Fixnum,
          start_instantly: true,
          end_instantly: false
        }.ignore_extra_keys!
      }.ignore_extra_keys!
      ReservationWorker.should_receive(:perform_async).with(anything, "start")
      post :create, format: :json, reservation: { starts_at: Time.current, ends_at: 2.hours.from_now, rcon: 'foo', password: 'bar', server_id: server.id }
      expect(response.body).to match_json_expression(json)
      response.status.should == 200
    end

    it "redirects to the new reservation json with a bad request status" do
      json = {
        reservation: {
          errors: wildcard_matcher,
        }.ignore_extra_keys!,
        servers: Array,
        whitelists: Array,
        server_configs: Array,
        actions: Hash
        }
      post :create, format: :json, reservation: {rcon: 'foo'}
      expect(response.body).to match_json_expression(json)
      response.status.should == 400
    end

    it "returns a general error if the json was invalid" do
      post :create, format: :json, something_invalid: {foo: 'bar'}
      response.status.should == 422
    end

  end

  describe "#destroy" do

    it "removes a future reservation" do
      reservation = create :reservation, user: @user, provisioned: false
      delete :destroy, id: reservation.id, format: :json
      response.status.should == 204
    end

    it "ends a current reservation" do
      reservation = create :reservation, user: @user, provisioned: true
      ReservationWorker.should_receive(:perform_async).with(reservation.id, "end")
      delete :destroy, id: reservation.id, format: :json
      json = {
        reservation: {
          end_instantly: true
        }.ignore_extra_keys!
      }.ignore_extra_keys!
      expect(response.body).to match_json_expression(json)
      response.status.should == 200
    end
  end

end
