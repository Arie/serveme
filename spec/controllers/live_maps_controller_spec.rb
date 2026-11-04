# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe LiveMapsController do
  around do |example|
    old = ENV.to_h.slice('STVTF_URL', 'STVTF_TOKEN_KEY')
    ENV['STVTF_URL'] = 'https://stv.tf'
    ENV['STVTF_TOKEN_KEY'] = '33' * 32
    example.run
  ensure
    %w[STVTF_URL STVTF_TOKEN_KEY].each { |k| old.key?(k) ? ENV[k] = old[k] : ENV.delete(k) }
  end

  let(:user) { create(:user) }

  before do
    sign_in user
    allow_any_instance_of(StvConnect).to receive(:check!) { |c| c }
  end

  it 'sends a checked address to the map server with the Steam uid of the user' do
    expect(StvtfToken).to receive(:start_url).with(connect: 'connect 1.2.3.4:27020; password "tv"', owner: user.uid).and_call_original
    post :create, params: { connect: ' 1.2.3.4:27020 tv ' }
    expect(response.location).to start_with('https://stv.tf/start?t=')
  end

  it 'shows what is wrong with the address' do
    allow_any_instance_of(StvConnect).to receive(:check!).and_raise(StvConnect::Error, 'No SourceTV answers at 1.2.3.4:27020')
    expect(StvtfToken).not_to receive(:start_url)
    post :create, params: { connect: '1.2.3.4:27020' }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(flash.now[:alert]).to include('No SourceTV answers')
  end

  it 'sends a demos.tf link to the map server to play' do
    allow_any_instance_of(DemostfDemo).to receive(:check!) { |d| d }
    expect(StvtfToken).to receive(:start_url).with(demo: 1_527_264, owner: user.uid).and_call_original
    post :create, params: { connect: 'https://demos.tf/1527264' }
    expect(response.location).to start_with('https://stv.tf/start?t=')
  end

  it 'says when demos.tf has no such demo' do
    allow_any_instance_of(DemostfDemo).to receive(:check!).and_raise(DemostfDemo::Error, 'demos.tf has no demo 1')
    expect(StvtfToken).not_to receive(:start_url)
    post :create, params: { connect: 'https://demos.tf/1' }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(flash.now[:alert]).to eq('demos.tf has no demo 1')
  end

  it 'needs a signed-in user' do
    sign_out user
    expect(StvtfToken).not_to receive(:start_url)
    post :create, params: { connect: '1.2.3.4:27020' }
    expect(response.location.to_s).not_to start_with('https://stv.tf')
  end

  describe '#index' do
    render_views

    let(:streamer) { create(:user).tap { |u| u.groups << Group.streamer_group } }
    let(:reservation) { create(:reservation, starts_at: 5.minutes.ago, ends_at: 1.hour.from_now) }
    let(:matches) do
      [ { 'id' => 'ab' * 16, 'reservation' => reservation.id, 'owner' => streamer.uid, 'server' => '1.2.3.4:27020', 'map' => 'cp_process_f12',
          'round' => 'running', 'round_time' => 221.0, 'time_left' => 1100.0, 'score' => { 'red' => 2, 'blue' => 1 },
          'viewers' => 4, 'peak' => 6, 'views' => 19, 'watching_for' => 1920, 'data_age' => 0.1, 'done' => false,
          'players' => [ { 'name' => 'moss', 'team' => 'red', 'class' => 'medic' } ] },
        { 'id' => 'cd' * 16, 'reservation' => nil, 'hostname' => 'Pasted server', 'server' => '203.0.113.24:27020', 'map' => 'cp_gullywash_f9',
          'round' => 'pregame', 'viewers' => 2, 'peak' => 2, 'views' => 2, 'watching_for' => 240, 'players' => [] } ]
    end

    before do
      Rails.cache.clear
      create(:player_statistic, reservation_player: create(:reservation_player, reservation: reservation, name: 'moss', steam_uid: '76561197960497430'))
      allow(StvtfHub).to receive(:matches).and_return([ matches.map { |m| StvtfHub::Match.new(m) }, nil ])
    end

    it 'hides reservations without players unless asked' do
      sign_in streamer
      empty = create(:reservation, starts_at: 5.minutes.ago, ends_at: 1.hour.from_now)
      get :index
      expect(response.body).not_to include(watch_reservation_path(empty))
      get :index, params: { empty: '1' }
      expect(response.body).to include(watch_reservation_path(empty))
    end

    it 'filters the reservations by a player, empty ones included' do
      sign_in streamer
      other = create(:reservation, starts_at: 5.minutes.ago, ends_at: 1.hour.from_now)
      get :index, params: { q: '76561197960497430' }
      expect(response.body).to include(watch_reservation_path(reservation), 'Clear search')
      expect(response.body).not_to include(watch_reservation_path(other))
      get :index, params: { q: other.user.nickname }
      expect(response.body).to include(watch_reservation_path(other))
    end

    it 'renders only the frame when the page refreshes or searches' do
      sign_in streamer
      request.headers['Turbo-Frame'] = 'live_stv'
      get :index
      expect(response).to render_template(layout: 'turbo_rails/frame')
      expect(response.body).to include(watch_reservation_path(reservation))
    end

    it 'is not for regular users' do
      get :index
      expect(response).to redirect_to(root_path)
    end

    it 'shows streamers the watched matches and the running reservations' do
      sign_in streamer
      get :index
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('cp_process_f12', 'Pasted server', 'Live · 3:41', 'class-icon-medic', "https://stv.tf/w/#{'ab' * 16}/overlay")
      expect(response.body).to include(watch_reservation_path(reservation), '4 watching')
    end

    it 'renders the redesign too' do
      sign_in streamer
      request.cookies['ui_v2'] = 'true'
      get :index
      expect(response).to render_template('layouts/application_v2')
      expect(response.body).to include('Pasted server', 'Join on stv.tf')
    end

    it 'still lists the reservations when stv.tf does not answer' do
      allow(StvtfHub).to receive(:matches).and_return([ [], 'execution expired' ])
      sign_in streamer
      get :index
      expect(response.body).to include("stv.tf isn't responding", watch_reservation_path(reservation))
      expect(response.body).not_to include('Watched on stv.tf')
    end
  end
end
