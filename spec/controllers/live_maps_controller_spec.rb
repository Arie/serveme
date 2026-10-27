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

  it 'sends a checked address to the map server with an unlimited token' do
    expect(StvtfToken).to receive(:start_url).with(connect: 'connect 1.2.3.4:27020; password "tv"', owner: nil).and_call_original
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
    expect(StvtfToken).to receive(:start_url).with(demo: 1_527_264, owner: nil).and_call_original
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
end
