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

  it 'sends a checked address to the map server, one match at a time for a user' do
    expect(StvtfToken).to receive(:start_url).with(connect: 'connect 1.2.3.4:27020; password "tv"', owner: user.uid).and_call_original
    post :create, params: { connect: ' 1.2.3.4:27020 tv ' }
    expect(response.location).to start_with('https://stv.tf/start?t=')
  end

  it 'gives admins unlimited matches' do
    user.groups << Group.admin_group
    expect(StvtfToken).to receive(:start_url).with(connect: 'connect 1.2.3.4:27020; password "tv"', owner: nil).and_call_original
    post :create, params: { connect: 'connect 1.2.3.4:27020; password "tv"' }
  end

  it 'shows what is wrong with the address' do
    allow_any_instance_of(StvConnect).to receive(:check!).and_raise(StvConnect::Error, 'No SourceTV answers at 1.2.3.4:27020')
    expect(StvtfToken).not_to receive(:start_url)
    post :create, params: { connect: '1.2.3.4:27020' }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(flash.now[:alert]).to include('No SourceTV answers')
  end

  it 'needs a signed-in user' do
    sign_out user
    expect(StvtfToken).not_to receive(:start_url)
    post :create, params: { connect: '1.2.3.4:27020' }
    expect(response.location.to_s).not_to start_with('https://stv.tf')
  end
end
