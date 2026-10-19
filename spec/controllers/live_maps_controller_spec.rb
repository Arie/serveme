# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe LiveMapsController do
  around do |example|
    old = ENV.to_h.slice('STVMAP_URL', 'STVMAP_TOKEN_KEY')
    ENV['STVMAP_URL'] = 'https://stv.tf'
    ENV['STVMAP_TOKEN_KEY'] = '33' * 32
    example.run
  ensure
    %w[STVMAP_URL STVMAP_TOKEN_KEY].each { |k| old.key?(k) ? ENV[k] = old[k] : ENV.delete(k) }
  end

  let(:user) { create(:user).tap { |u| u.groups << Group.admin_group } }

  before { sign_in user }

  it 'sends a pasted connect string to the map server with an unlimited token for an admin' do
    expect(StvmapToken).to receive(:start_url).with(connect: 'connect 1.2.3.4:27020; password "tv"', owner: nil).and_call_original
    post :create, params: { connect: ' connect 1.2.3.4:27020; password "tv" ' }
    expect(response.location).to start_with('https://stv.tf/start?t=')
  end

  it 'is for admins only' do
    sign_in create(:user)
    expect(StvmapToken).not_to receive(:start_url)
    post :create, params: { connect: 'connect 1.2.3.4:27020; password "tv"' }
    expect(response).to redirect_to(root_path)
  end

  it 'asks again for an empty connect string' do
    post :create, params: { connect: '' }
    expect(response).to redirect_to(live_map_path)
  end
end
