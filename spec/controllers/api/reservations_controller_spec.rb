# typed: false
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

    it 'includes docker hosts in the servers array with virtual IDs' do
      docker_host = create(:docker_host)
      post :find_servers, params: { reservation: { starts_at: Time.current.to_s, ends_at: (Time.current + 2.hours).to_s } }, format: :json

      servers = JSON.parse(response.body)['servers']
      docker_server = servers.find { |s| s['id'] == docker_host.virtual_server_id }
      expect(docker_server).to be_present
      expect(docker_server['id']).to eq(DockerHost::VIRTUAL_ID_OFFSET + docker_host.id)
      expect(docker_server['name']).to eq("#{docker_host.city} (Docker)")
      expect(docker_server['ip']).to eq(docker_host.hostname)
      expect(docker_server['sdr']).to eq(false)
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

    it 'exposes connect strings with the friendly hostname and connect urls with the numeric ip' do
      server = create(:server, ip: 'fakkelbrigade.eu', port: '27015', tv_port: '27020')
      server.update_column(:resolved_ip, '176.9.138.143')
      reservation = create :reservation, user: @user, server: server, password: 'foo', tv_password: 'bar'

      get :show, params: { id: reservation.id }, format: :json
      json = JSON.parse(response.body)['reservation']

      expect(json['connect_string']).to eq('connect fakkelbrigade.eu:27015; password "foo"')
      expect(json['stv_connect_string']).to eq('connect fakkelbrigade.eu:27020; password "bar"')
      expect(json['connect_url']).to eq('steam://connect/176.9.138.143:27015/foo')
      expect(json['stv_connect_url']).to eq('steam://connect/176.9.138.143:27020/bar')
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

    it 'does not double-book a server when a competitor commits while waiting for the per-server lock' do
      server = create :server, location: create(:location)
      other_user = create :user
      starts_at = Time.current
      ends_at = 2.hours.from_now

      # Simulate a competitor grabbing the same server in the window between our
      # first validation and acquiring the per-server lock.
      allow($lock).to receive(:synchronize) do |_key, &block|
        create(:reservation, user: other_user, server: server, starts_at: starts_at, ends_at: ends_at)
        block.call
      end

      post :create, format: :json, params: { reservation: { starts_at: starts_at, ends_at: ends_at, rcon: 'foo', password: 'bar', server_id: server.id } }

      expect(Reservation.where(server_id: server.id).count).to eq(1)
      response.status.should == 400
    end

    context 'with the legacy disable_democheck param' do
      let(:server) { create :server, location: create(:location) }

      it 'maps disable_democheck=true to democheck_mode disable' do
        post :create, format: :json, params: { reservation: { starts_at: Time.current, ends_at: 2.hours.from_now, rcon: 'foo', password: 'bar', server_id: server.id, disable_democheck: 'true' } }
        response.status.should == 200
        expect(Reservation.last.democheck_mode).to eq('disable')
      end

      it 'maps disable_democheck=false to democheck_mode kick' do
        post :create, format: :json, params: { reservation: { starts_at: Time.current, ends_at: 2.hours.from_now, rcon: 'foo', password: 'bar', server_id: server.id, disable_democheck: 'false' } }
        response.status.should == 200
        expect(Reservation.last.democheck_mode).to eq('kick')
      end

      it 'ignores disable_democheck when democheck_mode is also given' do
        post :create, format: :json, params: { reservation: { starts_at: Time.current, ends_at: 2.hours.from_now, rcon: 'foo', password: 'bar', server_id: server.id, democheck_mode: 'warn', disable_democheck: 'true' } }
        response.status.should == 200
        expect(Reservation.last.democheck_mode).to eq('warn')
      end
    end

    context 'with an invalid democheck_mode' do
      let(:server) { create :server, location: create(:location) }

      it 'returns a 4xx instead of raising when the value is not a known mode' do
        post :create, format: :json, params: { reservation: { starts_at: Time.current, ends_at: 2.hours.from_now, rcon: 'foo', password: 'bar', server_id: server.id, democheck_mode: 'Warn' } }
        expect(response.status).to eq(400)
        expect(Reservation.count).to eq(0)
      end
    end

    context 'with a docker host virtual server_id' do
      let(:docker_host) { create(:docker_host) }
      let(:virtual_server_id) { docker_host.virtual_server_id }

      it 'creates a reservation via DockerHostReservationCreator' do
        expect(CloudServerProvisionWorker).to receive(:perform_async)

        post :create, format: :json, params: {
          reservation: {
            starts_at: Time.current,
            ends_at: 2.hours.from_now,
            rcon: 'foo',
            password: 'bar',
            server_id: virtual_server_id
          }
        }

        expect(response.status).to eq(200)
        json = JSON.parse(response.body)
        expect(json['reservation']).to be_present
        expect(json['reservation']['server']['ip']).to be_present
      end

      it 'returns a 4xx instead of raising when democheck_mode is invalid' do
        post :create, format: :json, params: {
          reservation: {
            starts_at: Time.current,
            ends_at: 2.hours.from_now,
            rcon: 'foo',
            password: 'bar',
            server_id: virtual_server_id,
            democheck_mode: 'Warn'
          }
        }

        expect(response.status).to eq(400)
        expect(Reservation.count).to eq(0)
      end

      it 'returns 422 when docker host is at capacity' do
        allow_any_instance_of(DockerHost).to receive(:full_during?).and_return(true)

        post :create, format: :json, params: {
          reservation: {
            starts_at: Time.current,
            ends_at: 2.hours.from_now,
            rcon: 'foo',
            password: 'bar',
            server_id: virtual_server_id
          }
        }

        expect(response.status).to eq(422)
        json = JSON.parse(response.body)
        expect(json['error']).to be_present
      end
    end
  end

  describe '#update' do
    it 'updates a reservation and shows the results' do
      reservation = create(:reservation, ends_at: 1.hour.from_now, user: @user)
      new_ends_at = 90.minutes.from_now.change(usec: 0)
      json = {
        reservation: {
          starts_at: String,
          ends_at: new_ends_at.as_json,
          server_id: reservation.server_id,
          rcon: wildcard_matcher,
          password: 'bar',
          tv_password: wildcard_matcher,
          tv_relaypassword: wildcard_matcher,
          logsecret: wildcard_matcher,
          last_number_of_players: Integer,
          inactive_minute_counter: Integer,
          start_instantly: false,
          end_instantly: false,
          server: {
            ip_and_port: String
          }.ignore_extra_keys!
        }.ignore_extra_keys!
      }.ignore_extra_keys!

      expect(ReservationChangesWorker).to receive(:perform_async)

      patch :update, format: :json, params: { id: reservation.id, reservation: { ends_at: new_ends_at, password: 'bar' } }
      expect(response.body).to match_json_expression(json)
      response.status.should == 200
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

  describe '#log_lines' do
    let(:reservation) { create :reservation, user: @user }
    let(:log_path) { Rails.root.join('log', 'streaming', "#{reservation.logsecret}.log") }
    let(:log_lines) do
      [
        'L 06/07/2026 - 21:33:12: "Player<12><[U:1:231702]><>" connected, address "192.168.12.34:27005"',
        'L 06/07/2026 - 21:33:13: rcon from "10.0.0.5:54321": command "rcon_password "supersecret""',
        'L 06/07/2026 - 21:33:14: "Player<12><[U:1:231702]><Red>" say "hello world"'
      ]
    end

    before do
      FileUtils.mkdir_p(File.dirname(log_path))
      File.write(log_path, log_lines.join("\n") + "\n")
    end

    after do
      FileUtils.rm_f(log_path)
    end

    it 'returns the total line count and sanitized lines' do
      get :log_lines, params: { id: reservation.id }, format: :json

      expect(response.status).to eql 200
      json = JSON.parse(response.body)
      expect(json['reservation_id']).to eql reservation.id
      expect(json['start_line']).to eql 0
      expect(json['total_lines']).to eql 3
      expect(json['lines'].size).to eql 3
      expect(json['lines'][0]).to include('address "0.0.0.0:27005"')
      expect(json['lines'][1]).to include('rcon_password "*****"')
      expect(json['lines'][1]).to include('rcon from "0.0.0.0:54321"')
      expect(json['lines'][2]).to eql log_lines[2]
    end

    it 'returns only lines from start_line onwards' do
      get :log_lines, params: { id: reservation.id, start_line: 2 }, format: :json

      json = JSON.parse(response.body)
      expect(json['start_line']).to eql 2
      expect(json['total_lines']).to eql 3
      expect(json['lines']).to eql [ log_lines[2] ]
    end

    it 'returns no lines when start_line is at or beyond the end' do
      get :log_lines, params: { id: reservation.id, start_line: 3 }, format: :json

      json = JSON.parse(response.body)
      expect(json['total_lines']).to eql 3
      expect(json['lines']).to eql []
    end

    it 'returns a 404 when the logfile does not exist' do
      FileUtils.rm_f(log_path)

      get :log_lines, params: { id: reservation.id }, format: :json

      expect(response.status).to eql 404
    end

    it "returns a 404 for another user's reservation" do
      other_reservation = create :reservation, user: create(:user)

      get :log_lines, params: { id: other_reservation.id }, format: :json

      expect(response.status).to eql 404
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

      expect(response.status).to eql 200
      expect(JSON.parse(response.body)['reservations'].size).to eql(2)
    end

    it 'returns filtered results for admin' do
      @api_user.groups << Group.admin_group

      _reservation = create :reservation, inactive_minute_counter: 20, user: @user
      other_user = create(:user, uid: 'foo-bar-widget')
      _other_reservation = create :reservation, inactive_minute_counter: 20, user: other_user
      get :index, params: { limit: 10, offset: 0, steam_uid: other_user.uid }, format: :json

      expect(response.status).to eql 200
      expect(JSON.parse(response.body)['reservations'].size).to eql(1)
    end

    it "returns user's reservations for users" do
      _reservation = create :reservation, inactive_minute_counter: 20, user: @api_user
      _other_reservation = create :reservation, inactive_minute_counter: 20, user: create(:user)
      get :index, params: { limit: 10, offset: 0 }, format: :json

      expect(response.status).to eql 200
      expect(JSON.parse(response.body)['reservations'].size).to eql(1)
    end
  end

  context 'streamer access restrictions' do
    let(:streamer) do
      user = create(:user)
      user.groups << Group.streamer_group
      user
    end
    let(:other_user) { create(:user) }

    before do
      controller.stub(api_user: streamer)
    end

    describe '#index' do
      it 'allows streamers to list all reservations (read access)' do
        _own_reservation = create :reservation, user: streamer
        _other_reservation = create :reservation, user: other_user
        get :index, params: { limit: 10, offset: 0 }, format: :json

        expect(response.status).to eql 200
        expect(JSON.parse(response.body)['reservations'].size).to eql(2)
      end
    end

    describe '#update' do
      it 'prevents streamers from updating other users reservations' do
        reservation = create(:reservation, ends_at: 1.hour.from_now, user: other_user)

        expect {
          patch :update, format: :json, params: { id: reservation.id, reservation: { password: 'hacked' } }
        }.not_to change { reservation.reload.password }

        expect(response.status).to eql 404
      end

      it 'allows streamers to update their own reservations' do
        reservation = create(:reservation, ends_at: 1.hour.from_now, user: streamer)
        new_ends_at = 90.minutes.from_now.change(usec: 0)

        expect(ReservationChangesWorker).to receive(:perform_async)

        patch :update, format: :json, params: { id: reservation.id, reservation: { ends_at: new_ends_at, password: 'bar' } }

        expect(response.status).to eql 200
      end
    end
  end
end
