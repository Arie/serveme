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

  describe '#create' do
    before { @user.groups << Group.admin_group }

    it 'redirects to new with search params' do
      post :create, params: { league_request: { steam_uid: '76561198123456789', ip: '8.8.8.8' } }

      expect(response).to redirect_to(league_request_path(steam_uid: '76561198123456789', ip: '8.8.8.8'))
    end
  end
end
