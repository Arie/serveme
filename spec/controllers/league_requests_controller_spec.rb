# typed: false

require 'spec_helper'

describe LeagueRequestsController do
  before do
    @user = create :user
    sign_in @user
  end

  describe '#new' do
    context 'for non-admins' do
      it 'redirect to root for non admins' do
        get :new

        response.should redirect_to(root_path)
      end
    end

    context 'for admins' do
      before { @user.groups << Group.admin_group }

      it 'shows the search form' do
        get :new

        assigns(:results).should be_nil
      end

      it 'shows the search form again when the search was submitted empty' do
        get :new, params: { ip: '', steam_uid: '', reservation_ids: '' }

        assigns(:results).should be_nil
        expect(assigns(:league_request)).to be_a(LeagueRequest)
        expect(response).to render_template(:new)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'searches by reservation ids only' do
        player = create(:reservation_player)

        get :new, params: { ip: '', steam_uid: '', reservation_ids: player.reservation_id.to_s }

        expect(assigns(:results)).to include(player)
        expect(response).to render_template(:index)
      end

      it 'searches by steam_uid' do
        player = create(:reservation_player, steam_uid: '76561198123456789')

        get :new, params: { steam_uid: '76561198123456789' }

        expect(assigns(:results)).to include(player)
        expect(response).to render_template(:index)
      end

      it 'searches by ip' do
        player = create(:reservation_player, ip: '8.8.8.8')

        get :new, params: { ip: '8.8.8.8' }

        expect(assigns(:results)).to include(player)
      end

      it 'performs cross-reference search' do
        player = create(:reservation_player, steam_uid: 'abc', ip: '8.8.8.8')
        alt = create(:reservation_player, steam_uid: 'def', ip: '8.8.8.8')

        get :new, params: { steam_uid: 'abc', cross_reference: '1' }

        expect(assigns(:results)).to include(player)
        expect(assigns(:results)).to include(alt)
      end
    end
  end

  describe 'shared IP toggle in results' do
    render_views

    before do
      @user.groups << Group.league_admin_group
      create(:reservation_player, ip: '8.8.8.8')
    end

    it 'renders a shared IP toggle for every IP' do
      get :new, params: { ip: '8.8.8.8' }

      expect(response.body).to include(toggle_shared_ip_league_request_path)
      expect(response.body).to include('Mark as shared IP')
    end

    it 'marks shared IPs as such' do
      IpLookup.create!(ip: '8.8.8.8', shared_ip: true)

      get :new, params: { ip: '8.8.8.8' }

      expect(response.body).to include('Shared IP (LAN center')
    end

    it 'renders the toggle in the v2 layout too' do
      cookies[:ui_v2] = 'true'

      get :new, params: { ip: '8.8.8.8' }

      expect(response.body).to include(toggle_shared_ip_league_request_path)
    end
  end

  describe '#toggle_shared_ip' do
    before { @user.groups << Group.league_admin_group }

    it 'marks an IP that has no lookup row yet' do
      patch :toggle_shared_ip, params: { ip: '8.8.8.8', search_steam_uid: '76561198123456789', search_cross_reference: '1' }

      expect(IpLookup.find_by(ip: '8.8.8.8').shared_ip).to be true
      expect(response).to redirect_to(league_request_path(steam_uid: '76561198123456789', cross_reference: '1'))
    end

    it 'unmarks again on a second toggle' do
      IpLookup.create!(ip: '8.8.8.8', shared_ip: true, is_proxy: true)

      patch :toggle_shared_ip, params: { ip: '8.8.8.8' }

      lookup = IpLookup.find_by(ip: '8.8.8.8')
      expect(lookup.shared_ip).to be false
      expect(lookup.is_proxy).to be true
    end

    it 'is not available to regular users' do
      @user.groups.delete(Group.league_admin_group)

      patch :toggle_shared_ip, params: { ip: '8.8.8.8' }

      expect(IpLookup.find_by(ip: '8.8.8.8')).to be_nil
      expect(response).to redirect_to(root_path)
    end
  end

  describe '#create' do
    before { @user.groups << Group.admin_group }

    it 'redirects to new with search params' do
      post :create, params: { league_request: { steam_uid: '76561198123456789', ip: '8.8.8.8' } }

      expect(response).to redirect_to(league_request_path(steam_uid: '76561198123456789', ip: '8.8.8.8'))
    end
  end
end
