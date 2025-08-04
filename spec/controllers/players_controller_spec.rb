# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe PlayersController do
  before do
    Rails.cache.clear
  end

  describe '#index' do
    context 'as a regular user' do
      before do
        sign_in create(:user)
      end

      it 'renders the regular index view' do
        get :index
        expect(response).to render_template(:index)
      end

      it 'shows current players when they exist' do
        server1 = create :server, name: 'Alpha Server'
        server2 = create :server, name: 'Beta Server'

        reservation1 = create :reservation, server: server1
        reservation2 = create :reservation, server: server2

        player1 = create :reservation_player, reservation: reservation1, name: 'Player A'
        player2 = create :reservation_player, reservation: reservation2, name: 'Player B'

        create :player_statistic, reservation_player: player1, created_at: 1.minute.ago
        create :player_statistic, reservation_player: player2, created_at: 1.minute.ago

        get :index

        expect(response).to be_successful
        servers_with_players = assigns(:servers_with_players)
        expect(servers_with_players.length).to eq(2)
        expect(servers_with_players.first[:server].name).to eq('Alpha Server')
        expect(servers_with_players.second[:server].name).to eq('Beta Server')
      end

      it 'shows empty state when no players are active' do
        get :index

        expect(response).to be_successful
        servers_with_players = assigns(:servers_with_players)
        expect(servers_with_players).to be_empty
      end
    end

    context 'as an admin' do
      let(:admin) { create(:admin) }

      before do
        sign_in admin
      end

      it 'renders the admin view' do
        get :index
        expect(response).to render_template(:admins)
      end

      it 'provides the same data as regular users' do
        server = create :server, name: 'Test Server'
        reservation = create :reservation, server: server
        player = create :reservation_player, reservation: reservation, name: 'Test Player'
        create :player_statistic, reservation_player: player, created_at: 1.minute.ago

        get :index

        expect(response).to be_successful
        servers_with_players = assigns(:servers_with_players)
        expect(servers_with_players.length).to eq(1)
        expect(servers_with_players.first[:players].first[:reservation_player]).to eq(player)
      end
    end

    context 'as a league admin' do
      let(:league_admin) do
        user = create(:user)
        user.groups << Group.league_admin_group
        user
      end

      before do
        sign_in league_admin
      end

      it 'renders the admin view' do
        get :index
        expect(response).to render_template(:admins)
      end
    end

    context 'as a streamer' do
      let(:streamer) do
        user = create(:user)
        user.groups << Group.streamer_group
        user
      end

      before do
        sign_in streamer
      end

      it 'renders the admin view' do
        get :index
        expect(response).to render_template(:admins)
      end
    end
  end
end
