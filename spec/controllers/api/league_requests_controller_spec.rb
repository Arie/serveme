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
    controller.stub(api_user: @user)
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
end
