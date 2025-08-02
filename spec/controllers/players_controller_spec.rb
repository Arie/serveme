# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe PlayersController do
  before do
    Rails.cache.clear
  end

  describe '#index' do
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
end
