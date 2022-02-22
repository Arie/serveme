# frozen_string_literal: true

require 'spec_helper'

describe Api::ReservationsController do
  render_views

  before do
    @user = create :user
    controller.stub(api_user: @user)
  end

  describe '#new' do
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

  describe '#find_servers' do
    it 'returns a reservation json to be filled in with available servers' do
      post :find_servers, params: { reservation: { starts_at: Time.current.to_s, ends_at: (Time.current + 2.hours).to_s } }, format: :json
      json = {
        reservation: {
          starts_at: String,
          ends_at: String,
          rcon: wildcard_matcher,
          password: wildcard_matcher,
          tv_password: wildcard_matcher,
          tv_relaypassword: wildcard_matcher
        }.ignore_extra_keys!,
        servers: Array,
        whitelists: Array,
        server_configs: Array,
        actions: Hash
      }
      expect(response.body).to match_json_expression(json)
    end
  end

  describe '#show' do
    it 'returns a json of a reservation' do
      reservation = create :reservation, user: @user
      get :show, params: { id: reservation.id }, format: :json
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

    it 'returns a 404 for an unknown reservation' do
      get :show, params: { id: -1 }
      response.status.should == 404
    end
  end

  describe '#create' do
    it 'saves a valid reservation and shows the results' do
      server = create :server, location: create(:location)
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
          last_number_of_players: Integer,
          inactive_minute_counter: Integer,
          start_instantly: true,
          end_instantly: false,
          server: {
            ip_and_port: String
          }.ignore_extra_keys!
        }.ignore_extra_keys!
      }.ignore_extra_keys!
      ReservationWorker.should_receive(:perform_async).with(anything, 'start')
      post :create, format: :json, params: { reservation: { starts_at: Time.current, ends_at: 2.hours.from_now, rcon: 'foo', password: 'bar', server_id: server.id } }
      expect(response.body).to match_json_expression(json)
      response.status.should == 200
    end

    it 'redirects to the new reservation json with a bad request status' do
      json = {
        reservation: {
          errors: wildcard_matcher
        }.ignore_extra_keys!,
        servers: Array,
        whitelists: Array,
        server_configs: Array,
        actions: Hash
      }
      post :create, format: :json, params: { reservation: { rcon: 'foo' } }
      expect(response.body).to match_json_expression(json)
      response.status.should == 400
    end

    it 'returns a general error if the json was invalid' do
      post :create, format: :json, params: { something_invalid: { foo: 'bar' } }
      response.status.should == 422
    end
  end

  describe '#destroy' do
    it 'removes a future reservation' do
      reservation = create :reservation, user: @user, starts_at: 1.hour.from_now
      delete :destroy, params: { id: reservation.id }, format: :json
      response.status.should == 204
    end

    it 'ends a current reservation' do
      reservation = create :reservation, user: @user, provisioned: true
      ReservationWorker.should_receive(:perform_async).with(reservation.id, 'end')
      delete :destroy, params: { id: reservation.id }, format: :json
      json = {
        reservation: {
          end_instantly: true
        }.ignore_extra_keys!
      }.ignore_extra_keys!
      expect(response.body).to match_json_expression(json)
      response.status.should == 200
    end
  end

  describe '#idle_reset' do
    it 'resets the idle timer for a reservation and returns the modified reservation' do
      reservation = create :reservation, inactive_minute_counter: 20, user: @user
      json = {
        reservation: {
          inactive_minute_counter: 0
        }.ignore_extra_keys!
      }.ignore_extra_keys!

      post :idle_reset, params: { id: reservation.id }, format: :json

      expect(response.status).to eql 200
      expect(response.body).to match_json_expression(json)
    end
  end

  describe '#extends' do
    it 'extends the reservation' do
      reservation = create :reservation, user: @user, starts_at: Time.current, ends_at: 50.minutes.from_now, provisioned: true

      post :extend, params: { id: reservation.id }, format: :json

      expect(response.status).to eql 200
    end

    it 'returns bad request if not extendable' do
      reservation = create :reservation, user: @user, starts_at: Time.current, ends_at: 50.minutes.from_now, provisioned: true
      _conflicting_reservation = create :reservation, server_id: reservation.server_id, starts_at: 1.hour.from_now, ends_at: 2.hours.from_now

      post :extend, params: { id: reservation.id }, format: :json

      expect(response.status).to eql 400
    end
  end

  describe '#index' do
    before do
      @api_user = create :user
      controller.stub(api_user: @api_user)
    end

    it 'returns all reservations for admins' do
      @api_user.groups << Group.admin_group

      _reservation = create :reservation, inactive_minute_counter: 20, user: @user
      _other_reservation = create :reservation, inactive_minute_counter: 20, user: create(:user)
      get :index, params: { limit: 10, offset: 0 }, format: :json

      response.status.should == 200
      expect(JSON.parse(response.body)['reservations'].size).to eql(2)
    end

    it 'returns filtered results for admin' do
      @api_user.groups << Group.admin_group

      _reservation = create :reservation, inactive_minute_counter: 20, user: @user
      other_user = create(:user, uid: 'foo-bar-widget')
      _other_reservation = create :reservation, inactive_minute_counter: 20, user: other_user
      get :index, params: { limit: 10, offset: 0, steam_uid: other_user.uid }, format: :json

      response.status.should == 200
      expect(JSON.parse(response.body)['reservations'].size).to eql(1)
    end

    it "returns user's reservations for users" do
      _reservation = create :reservation, inactive_minute_counter: 20, user: @api_user
      _other_reservation = create :reservation, inactive_minute_counter: 20, user: create(:user)
      get :index, params: { limit: 10, offset: 0 }, format: :json

      response.status.should == 200
      expect(JSON.parse(response.body)['reservations'].size).to eql(1)
    end
  end
end
