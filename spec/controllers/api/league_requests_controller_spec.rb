# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe Api::LeagueRequestsController do
  render_views

  before do
    @user = create :user
    @user.groups << Group.league_admin_group
    @suspect_uid = 'suspect_uid'
    @suspect_ip = '127.0.0.2'
    @reservation_player = create(:reservation_player, steam_uid: @suspect_uid, ip: @suspect_ip)
    @other_player = create(:reservation_player, steam_uid: 'other-uid', ip: '127.0.0.3')
    allow(controller).to receive(:api_user).and_return(@user)
  end

  describe '#index' do
    it 'renders a json with leugue request results' do
      get :index, format: :json, params: { league_request: { cross_reference: true, ip: @suspect_ip } }
      expect(response.body).to include(@suspect_uid)
      expect(response.body).to include(@suspect_ip)
      expect(response.body).not_to include(@other_player.steam_uid)
      expect(response.body).not_to include(@other_player.ip)
    end
  end

  describe 'authorization' do
    let(:league_admin) do
      create(:user, uid: 'league-admin-uid').tap { |u| u.groups << Group.league_admin_group }
    end

    it 'forbids a trusted_api api_user impersonating a league admin via steam_uid' do
      trusted = create(:user, uid: 'trusted-uid')
      trusted.groups << Group.trusted_api_group
      allow(controller).to receive(:api_user).and_return(trusted)

      get :index, format: :json, params: { steam_uid: league_admin.uid, league_request: { ip: @suspect_ip } }

      expect(response).to have_http_status(:forbidden)
    end

    it 'allows a genuine league_admin api_user' do
      allow(controller).to receive(:api_user).and_return(league_admin)

      get :index, format: :json, params: { league_request: { ip: @suspect_ip } }

      expect(response).to have_http_status(:ok)
    end

    it 'allows an admin api_user' do
      admin = create(:user, uid: 'admin-uid')
      admin.groups << Group.admin_group
      allow(controller).to receive(:api_user).and_return(admin)

      get :index, format: :json, params: { league_request: { ip: @suspect_ip } }

      expect(response).to have_http_status(:ok)
    end
  end
end
